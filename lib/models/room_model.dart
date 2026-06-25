class RoomModel {
  final String roomId;
  final String roomCode;
  final String hostId;
  final String? guestId;
  final String status; // waiting / playing / finished / abandoned
  final List<String> board;
  final String playerX;
  final String playerO;
  final String currentTurn;
  final String? winner;
  final String? result; // win / draw / abandoned
  final int moveCount;
  final String? rematchRequestBy; // uid of who requested rematch
  final String? rematchRoomId;    // new room id once both accept

  RoomModel({
    required this.roomId,
    required this.roomCode,
    required this.hostId,
    this.guestId,
    required this.status,
    required this.board,
    required this.playerX,
    required this.playerO,
    required this.currentTurn,
    this.winner,
    this.result,
    this.moveCount = 0,
    this.rematchRequestBy,
    this.rematchRoomId,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) => RoomModel(
        roomId: id,
        roomCode: map['roomCode'] ?? '',
        hostId: map['hostId'] ?? '',
        guestId: map['guestId'],
        status: map['status'] ?? 'waiting',
        board: List<String>.from(map['board'] ?? List.filled(9, '')),
        playerX: map['playerX'] ?? '',
        playerO: map['playerO'] ?? '',
        currentTurn: map['currentTurn'] ?? '',
        winner: map['winner'],
        result: map['result'],
        moveCount: map['moveCount'] ?? 0,
        rematchRequestBy: map['rematchRequestBy'],
        rematchRoomId: map['rematchRoomId'],
      );

  Map<String, dynamic> toMap() => {
        'roomCode': roomCode,
        'hostId': hostId,
        'guestId': guestId,
        'status': status,
        'board': board,
        'playerX': playerX,
        'playerO': playerO,
        'currentTurn': currentTurn,
        'winner': winner,
        'result': result,
        'moveCount': moveCount,
        'rematchRequestBy': rematchRequestBy,
        'rematchRoomId': rematchRoomId,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
}
