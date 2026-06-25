class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status; // pending / accepted / declined

  FriendRequest({required this.id, required this.fromUid, required this.toUid, required this.status});

  factory FriendRequest.fromMap(Map<String, dynamic> map, String id) => FriendRequest(
        id: id,
        fromUid: map['fromUid'] ?? '',
        toUid: map['toUid'] ?? '',
        status: map['status'] ?? 'pending',
      );

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      };
}
