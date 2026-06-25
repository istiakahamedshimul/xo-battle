import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/chat_message.dart';
import '../models/friend_request.dart';

final authServiceProvider = Provider((_) => AuthService());
final roomServiceProvider = Provider((_) => RoomService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authState;
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserModel.fromMap(s.data()!, uid) : null);
});

final roomStreamProvider = StreamProvider.family<RoomModel?, String>((ref, roomId) {
  return ref.read(roomServiceProvider).watchRoom(roomId);
});

final chatStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.read(roomServiceProvider).watchMessages(roomId);
});

final leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.read(roomServiceProvider).getLeaderboard();
});

final incomingRequestsProvider = StreamProvider.family<List<FriendRequest>, String>((ref, uid) {
  return ref.read(roomServiceProvider).watchIncomingRequests(uid);
});

final friendsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.read(roomServiceProvider).watchFriends(uid);
});

final incomingChallengesProvider = StreamProvider.family<List<RoomModel>, String>((ref, uid) {
  return ref.read(roomServiceProvider).watchIncomingChallenges(uid);
});

/// Returns true if [viewerUid] is already friends with [targetUid]
final isFriendProvider = FutureProvider.family<bool, ({String viewer, String target})>((ref, ids) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(ids.viewer)
      .collection('friends')
      .doc(ids.target)
      .get();
  return doc.exists;
});

/// Checks if a pending friend request already exists from viewer to target
final hasPendingRequestProvider = FutureProvider.family<bool, ({String viewer, String target})>((ref, ids) async {
  final snap = await FirebaseFirestore.instance
      .collection('friendRequests')
      .where('fromUid', isEqualTo: ids.viewer)
      .where('toUid', isEqualTo: ids.target)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
});

final themeProvider = StateProvider<bool>((ref) => false); // false = light

// Timer provider: seconds remaining per move
class TimerNotifier extends StateNotifier<int> {
  TimerNotifier() : super(30);

  void reset() => state = 30;
  void tick() => state = state > 0 ? state - 1 : 0;
  bool get expired => state == 0;
}

final timerProvider = StateNotifierProvider<TimerNotifier, int>((_) => TimerNotifier());
