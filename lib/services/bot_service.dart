import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Difficulty labels for bot profiles. Gameplay uses perfect play for every bot.
enum BotDifficulty { easy, medium, hard }

class BotProfile {
  final String uid;
  final String name;
  final String avatar;
  final BotDifficulty difficulty;
  final int points;
  final int wins;
  final int losses;
  final int draws;
  final int totalMatches;

  const BotProfile({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.difficulty,
    required this.points,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalMatches,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'avatar': avatar,
        'points': points,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'totalMatches': totalMatches,
        'winRate': totalMatches == 0 ? 0.0 : wins / totalMatches,
        'currentStreak': 0,
        'bestStreak': wins > 5 ? wins ~/ 3 : 0,
        'isBot': true,
        'botDifficulty': difficulty.name,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
}

class BotService {
  static final _db = FirebaseFirestore.instance;
  static final _rng = Random();

  /// 10 realistic bot profiles with varied stats
  static const List<BotProfile> botProfiles = [
    BotProfile(uid: 'bot_nova',    name: 'Nova',    avatar: 'avatar_3', difficulty: BotDifficulty.hard,   points: 312, wins: 98,  losses: 12, draws: 8,  totalMatches: 118),
    BotProfile(uid: 'bot_blaze',   name: 'Blaze',   avatar: 'avatar_6', difficulty: BotDifficulty.hard,   points: 285, wins: 91,  losses: 18, draws: 5,  totalMatches: 114),
    BotProfile(uid: 'bot_cipher',  name: 'Cipher',  avatar: 'avatar_2', difficulty: BotDifficulty.medium, points: 198, wins: 62,  losses: 34, draws: 10, totalMatches: 106),
    BotProfile(uid: 'bot_pixel',   name: 'Pixel',   avatar: 'avatar_4', difficulty: BotDifficulty.medium, points: 174, wins: 55,  losses: 40, draws: 9,  totalMatches: 104),
    BotProfile(uid: 'bot_storm',   name: 'Storm',   avatar: 'avatar_1', difficulty: BotDifficulty.medium, points: 156, wins: 48,  losses: 45, draws: 12, totalMatches: 105),
    BotProfile(uid: 'bot_luna',    name: 'Luna',    avatar: 'avatar_5', difficulty: BotDifficulty.easy,   points: 87,  wins: 27,  losses: 61, draws: 8,  totalMatches: 96),
    BotProfile(uid: 'bot_rex',     name: 'Rex',     avatar: 'avatar_1', difficulty: BotDifficulty.easy,   points: 72,  wins: 22,  losses: 68, draws: 6,  totalMatches: 96),
    BotProfile(uid: 'bot_echo',    name: 'Echo',    avatar: 'avatar_2', difficulty: BotDifficulty.easy,   points: 63,  wins: 19,  losses: 72, draws: 5,  totalMatches: 96),
    BotProfile(uid: 'bot_vortex',  name: 'Vortex',  avatar: 'avatar_3', difficulty: BotDifficulty.hard,   points: 267, wins: 84,  losses: 22, draws: 7,  totalMatches: 113),
    BotProfile(uid: 'bot_glitch',  name: 'Glitch',  avatar: 'avatar_4', difficulty: BotDifficulty.medium, points: 141, wins: 43,  losses: 50, draws: 11, totalMatches: 104),
  ];

  /// Seed all bot profiles into Firestore (call once, idempotent)
  static Future<void> seedBots() async {
    final batch = _db.batch();
    int newBots = 0;
    for (final bot in botProfiles) {
      final ref = _db.collection('users').doc(bot.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        batch.set(ref, bot.toFirestore());
        newBots++;
      }
    }
    if (newBots > 0) await batch.commit();
  }

  /// Pick a random bot profile
  static BotProfile randomBot() => botProfiles[_rng.nextInt(botProfiles.length)];

  static bool isBot(String uid) => uid.startsWith('bot_');

  // ── AI Logic (Minimax) ────────────────────────────────────────────────────

  /// Returns the best cell index for the bot to play.
  static int getBotMove(List<String> board, String botSymbol, BotDifficulty difficulty) {
    final humanSymbol = botSymbol == 'X' ? 'O' : 'X';
    return _negamaxBestMove(board, botSymbol, humanSymbol);
  }

  static int? _findWinningMove(List<String> board, String symbol) {
    for (int i = 0; i < 9; i++) {
      if (board[i].isNotEmpty) continue;
      final copy = List<String>.from(board)..[i] = symbol;
      if (_checkWinner(copy) == symbol) return i;
    }
    return null;
  }

  static int _negamaxBestMove(List<String> board, String botSymbol, String humanSymbol) {
    final availableMoves = _orderedEmptyCells(board);
    if (availableMoves.isEmpty) return -1;

    final winningMove = _findWinningMove(board, botSymbol);
    if (winningMove != null) return winningMove;

    final blockingMove = _findWinningMove(board, humanSymbol);
    if (blockingMove != null) return blockingMove;

    int bestScore = -1000;
    final bestMoves = <int>[];
    for (final i in availableMoves) {
      final copy = List<String>.from(board)..[i] = botSymbol;
      final score = -_negamax(
        copy,
        currentSymbol: humanSymbol,
        botSymbol: botSymbol,
        humanSymbol: humanSymbol,
        depth: 1,
        alpha: -1000,
        beta: 1000,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(i);
      } else if (score == bestScore) {
        bestMoves.add(i);
      }
    }
    return bestMoves[_rng.nextInt(bestMoves.length)];
  }

  static int _negamax(
    List<String> board, {
    required String currentSymbol,
    required String botSymbol,
    required String humanSymbol,
    required int depth,
    required int alpha,
    required int beta,
  }) {
    final winner = _checkWinner(board);
    if (winner != null) {
      final winnerScore = winner == botSymbol ? 10 - depth : depth - 10;
      return currentSymbol == botSymbol ? winnerScore : -winnerScore;
    }
    if (!board.contains('')) return 0;

    final nextSymbol = currentSymbol == botSymbol ? humanSymbol : botSymbol;
    var best = -1000;
    var localAlpha = alpha;

    for (final i in _orderedEmptyCells(board)) {
      board[i] = currentSymbol;
      final score = -_negamax(
        board,
        currentSymbol: nextSymbol,
        botSymbol: botSymbol,
        humanSymbol: humanSymbol,
        depth: depth + 1,
        alpha: -beta,
        beta: -localAlpha,
      );
      board[i] = '';

      best = max(best, score);
      localAlpha = max(localAlpha, score);
      if (localAlpha >= beta) break;
    }
    return best;
  }

  static List<int> _orderedEmptyCells(List<String> board) {
    const preferredOrder = [4, 0, 2, 6, 8, 1, 3, 5, 7];
    return [for (final i in preferredOrder) if (board[i].isEmpty) i];
  }

  static String? _checkWinner(List<String> board) {
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

  // ── Bot move execution (called from game screen) ──────────────────────────

  StreamSubscription<DocumentSnapshot>? _botSub;

  /// Start watching [roomId] and make bot moves whenever it's the bot's turn.
  void startBotEngine(String roomId, String botUid, String botSymbol, BotDifficulty difficulty) {
    _botSub?.cancel();
    _botSub = _db.collection('rooms').doc(roomId).snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'playing') return;
      if (data['currentTurn'] != botUid) return;

      final board = List<String>.from(data['board']);
      if (!board.contains('')) return;

      final humanUid = botUid == data['playerX'] ? data['playerO'] : data['playerX'];

      // Human-like delay: 0.8s–2.2s
      final delay = 800 + _rng.nextInt(1400);
      await Future.delayed(Duration(milliseconds: delay));

      // Re-check it's still bot's turn after delay
      final fresh = await _db.collection('rooms').doc(roomId).get();
      if (!fresh.exists) return;
      final freshData = fresh.data()!;
      if (freshData['status'] != 'playing') return;
      if (freshData['currentTurn'] != botUid) return;

      final freshBoard = List<String>.from(freshData['board']);
      final move = getBotMove(freshBoard, botSymbol, difficulty);
      if (move < 0) return;
      if (freshBoard[move].isNotEmpty) return;
      freshBoard[move] = botSymbol;

      final winner = _checkWinner(freshBoard);
      final isDraw = winner == null && !freshBoard.contains('');

      final update = <String, dynamic>{
        'board': freshBoard,
        'currentTurn': humanUid,
        'moveCount': FieldValue.increment(1),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (winner != null) {
        update['status'] = 'finished';
        update['winner'] = botUid;
        update['result'] = 'win';
      } else if (isDraw) {
        update['status'] = 'finished';
        update['result'] = 'draw';
      }

      await _db.collection('rooms').doc(roomId).update(update);

      // Update stats only when game ends
      if (update.containsKey('status')) {
        await _updateBotStats(
          playerX: freshData['playerX'],
          playerO: freshData['playerO'],
          winnerId: winner != null ? botUid : null,
          isDraw: isDraw,
          botUid: botUid,
        );
      }
    });
  }

  void stopBotEngine() => _botSub?.cancel();

  Future<void> _updateBotStats({
    required String playerX,
    required String playerO,
    required String? winnerId,
    required bool isDraw,
    required String botUid,
  }) async {
    final batch = _db.batch();
    final humanUid = botUid == playerX ? playerO : playerX;

    // Only update real user stats (bot stats are cosmetic seeds)
    final humanRef = _db.collection('users').doc(humanUid);
    if (isDraw) {
      batch.update(humanRef, {
        'draws': FieldValue.increment(1),
        'totalMatches': FieldValue.increment(1),
        'points': FieldValue.increment(1),
        'currentStreak': 0,
      });
    } else if (winnerId == humanUid) {
      batch.update(humanRef, {
        'wins': FieldValue.increment(1),
        'totalMatches': FieldValue.increment(1),
        'points': FieldValue.increment(3),
        'currentStreak': FieldValue.increment(1),
      });
    } else {
      batch.update(humanRef, {
        'losses': FieldValue.increment(1),
        'totalMatches': FieldValue.increment(1),
        'currentStreak': 0,
      });
    }
    await batch.commit();
  }
}
