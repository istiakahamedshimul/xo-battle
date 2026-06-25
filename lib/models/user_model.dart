class UserModel {
  final String uid;
  final String name;
  final String avatar;
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final int points;
  final int currentStreak;
  final int bestStreak;

  UserModel({
    required this.uid,
    required this.name,
    this.avatar = 'avatar_1',
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.points = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  double get winRate => totalMatches == 0 ? 0 : wins / totalMatches;

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) => UserModel(
        uid: uid,
        name: map['name'] ?? 'Player',
        avatar: map['avatar'] ?? 'avatar_1',
        totalMatches: map['totalMatches'] ?? 0,
        wins: map['wins'] ?? 0,
        losses: map['losses'] ?? 0,
        draws: map['draws'] ?? 0,
        points: map['points'] ?? 0,
        currentStreak: map['currentStreak'] ?? 0,
        bestStreak: map['bestStreak'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'avatar': avatar,
        'totalMatches': totalMatches,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'points': points,
        'winRate': winRate,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  UserModel copyWith({
    String? name,
    String? avatar,
    int? totalMatches,
    int? wins,
    int? losses,
    int? draws,
    int? points,
    int? currentStreak,
    int? bestStreak,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        totalMatches: totalMatches ?? this.totalMatches,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
        points: points ?? this.points,
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
      );
}
