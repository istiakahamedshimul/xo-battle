import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/chat_message.dart';
import '../models/friend_request.dart';

class RoomService {
  final _db = FirebaseFirestore.instance;

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Room ───────────────────────────────────────────────────────────────────

  Future<RoomModel> createRoom(String hostId) async {
    final code = _generateCode();
    final expires = DateTime.now().add(const Duration(minutes: 30));
    final ref = _db.collection('rooms').doc();

    final data = {
      'roomCode': code,
      'hostId': hostId,
      'guestId': null,
      'status': 'waiting',
      'board': List.filled(9, ''),
      'playerX': hostId,
      'playerO': '',
      'currentTurn': hostId,
      'winner': null,
      'result': null,
      'moveCount': 0,
      'rematchRequestBy': null,
      'rematchRoomId': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': expires.toIso8601String(),
    };
    await ref.set(data);
    return RoomModel.fromMap(data, ref.id);
  }

  Future<RoomModel?> joinRoomByCode(String code, String guestId) async {
    final query = await _db
        .collection('rooms')
        .where('roomCode', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    await doc.reference.update({
      'guestId': guestId,
      'playerO': guestId,
      'status': 'waiting',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    final updated = await doc.reference.get();
    return RoomModel.fromMap(updated.data()!, updated.id);
  }

  Future<RoomModel?> joinRandomRoom(String userId) async {
    final query = await _db
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .limit(5)
        .get();

    final available = query.docs
        .where((d) => d['hostId'] != userId && (d['challengedBy'] == null))
        .toList();
    if (available.isNotEmpty) {
      final doc = available.first;
      await doc.reference.update({
        'guestId': userId,
        'playerO': userId,
        'status': 'waiting',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      final updated = await doc.reference.get();
      return RoomModel.fromMap(updated.data()!, updated.id);
    }
    return null;
  }

  Stream<RoomModel?> watchRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return RoomModel.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> startGame(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> makeMove(String roomId, int cellIndex, String playerId,
      String symbol, String nextTurn) async {
    final roomRef = _db.collection('rooms').doc(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(roomRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      if (data['status'] != 'playing') return;
      if (data['currentTurn'] != playerId) return;

      final board = List<String>.from(data['board']);
      if (board[cellIndex].isNotEmpty) return;
      board[cellIndex] = symbol;

      final winner = _checkWinner(board);
      final isDraw = winner == null && !board.contains('');

      final update = <String, dynamic>{
        'board': board,
        'currentTurn': nextTurn,
        'moveCount': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (winner != null) {
        update['status'] = 'finished';
        update['winner'] = playerId;
        update['result'] = 'win';
      } else if (isDraw) {
        update['status'] = 'finished';
        update['result'] = 'draw';
      }

      tx.update(roomRef, update);
    });

    final snap = await roomRef.get();
    final data = snap.data()!;

    await roomRef.collection('moves').add({
      'playerId': playerId,
      'cellIndex': cellIndex,
      'symbol': symbol,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (data['status'] == 'finished') {
      if (data['result'] == 'win') {
        await _updateStats(data['playerX'], data['playerO'], playerId, false);
      } else if (data['result'] == 'draw') {
        await _updateStats(data['playerX'], data['playerO'], null, true);
      }
    }
  }

  Future<void> abandonRoom(String roomId, String leavingPlayerId) async {
    final room = await _db.collection('rooms').doc(roomId).get();
    if (!room.exists || room['status'] == 'finished') return;

    final playerX = room['playerX'] as String;
    final playerO = room['playerO'] as String;
    final winner = leavingPlayerId == playerX ? playerO : playerX;

    await _db.collection('rooms').doc(roomId).update({
      'status': 'finished',
      'result': 'abandoned',
      'winner': winner,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (winner.isNotEmpty) {
      await _db.collection('users').doc(winner).update({
        'points': FieldValue.increment(2),
        'totalMatches': FieldValue.increment(1),
        'wins': FieldValue.increment(1),
      });
    }
    if (leavingPlayerId.isNotEmpty) {
      await _db.collection('users').doc(leavingPlayerId).update({
        'totalMatches': FieldValue.increment(1),
        'losses': FieldValue.increment(1),
        'currentStreak': 0,
      });
    }
  }

  // ── Rematch (mutual consent) ───────────────────────────────────────────────

  Future<void> requestRematch(String roomId, String requesterId) async {
    await _db.collection('rooms').doc(roomId).update({
      'rematchRequestBy': requesterId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Opponent accepts: creates new room and writes rematchRoomId so both
  /// players' streams navigate at the same time.
  Future<void> acceptRematch(String oldRoomId, String playerX, String playerO) async {
    final code = _generateCode();
    final ref = _db.collection('rooms').doc();
    final data = {
      'roomCode': code,
      'hostId': playerO, // roles swap
      'guestId': playerX,
      'status': 'waiting',
      'board': List.filled(9, ''),
      'playerX': playerO,
      'playerO': playerX,
      'currentTurn': playerO,
      'winner': null,
      'result': null,
      'moveCount': 0,
      'rematchRequestBy': null,
      'rematchRoomId': null,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
    };
    await ref.set(data);
    await _db.collection('rooms').doc(oldRoomId).update({'rematchRoomId': ref.id});
  }

  Future<void> declineRematch(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'rematchRequestBy': null,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Friends ────────────────────────────────────────────────────────────────

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    final existing = await _db
        .collection('friendRequests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _db.collection('friendRequests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Accept request → adds friends → creates challenge room → returns it.
  Future<RoomModel> acceptFriendRequest(
      String requestId, String acceptorUid, String senderUid) async {
    final batch = _db.batch();
    batch.update(_db.collection('friendRequests').doc(requestId), {'status': 'accepted'});
    batch.set(
      _db.collection('users').doc(acceptorUid).collection('friends').doc(senderUid),
      {'uid': senderUid, 'since': DateTime.now().toIso8601String()},
    );
    batch.set(
      _db.collection('users').doc(senderUid).collection('friends').doc(acceptorUid),
      {'uid': acceptorUid, 'since': DateTime.now().toIso8601String()},
    );
    await batch.commit();

    final code = _generateCode();
    final ref = _db.collection('rooms').doc();
    final data = {
      'roomCode': code,
      'hostId': senderUid,
      'guestId': acceptorUid,
      'status': 'waiting',
      'board': List.filled(9, ''),
      'playerX': senderUid,
      'playerO': acceptorUid,
      'currentTurn': senderUid,
      'winner': null,
      'result': null,
      'moveCount': 0,
      'rematchRequestBy': null,
      'rematchRoomId': null,
      'challengedBy': senderUid,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
    };
    await ref.set(data);
    return RoomModel.fromMap(data, ref.id);
  }

  Future<void> challengeFriend(String myUid, String friendUid) async {
    final code = _generateCode();
    final ref = _db.collection('rooms').doc();
    await ref.set({
      'roomCode': code,
      'hostId': myUid,
      'guestId': friendUid,
      'status': 'waiting',
      'board': List.filled(9, ''),
      'playerX': myUid,
      'playerO': friendUid,
      'currentTurn': myUid,
      'winner': null,
      'result': null,
      'moveCount': 0,
      'rematchRequestBy': null,
      'rematchRoomId': null,
      'challengedBy': myUid,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
    });
  }

  Stream<List<FriendRequest>> watchIncomingRequests(String uid) {
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => FriendRequest.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchFriends(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  Stream<List<RoomModel>> watchIncomingChallenges(String uid) {
    return _db
        .collection('rooms')
        .where('guestId', isEqualTo: uid)
        .where('status', isEqualTo: 'waiting')
        .where('challengedBy', isNotEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList());
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String roomId, ChatMessage msg) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add(msg.toMap());
  }

  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.data())).toList());
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final query = await _db
        .collection('users')
        .orderBy('points', descending: true)
        .limit(50)
        .get();
    return query.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  String? _checkWinner(List<String> board) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      if (board[line[0]].isNotEmpty &&
          board[line[0]] == board[line[1]] &&
          board[line[1]] == board[line[2]]) {
        return board[line[0]];
      }
    }
    return null;
  }

  Future<void> _updateStats(
      String playerX, String playerO, String? winnerId, bool isDraw) async {
    final batch = _db.batch();
    for (final uid in [playerX, playerO]) {
      final ref = _db.collection('users').doc(uid);
      if (isDraw) {
        batch.update(ref, {
          'draws': FieldValue.increment(1),
          'totalMatches': FieldValue.increment(1),
          'points': FieldValue.increment(1),
          'currentStreak': 0,
        });
      } else if (uid == winnerId) {
        batch.update(ref, {
          'wins': FieldValue.increment(1),
          'totalMatches': FieldValue.increment(1),
          'points': FieldValue.increment(3),
          'currentStreak': FieldValue.increment(1),
        });
      } else {
        batch.update(ref, {
          'losses': FieldValue.increment(1),
          'totalMatches': FieldValue.increment(1),
          'currentStreak': 0,
        });
      }
    }
    await batch.commit();
  }
}
