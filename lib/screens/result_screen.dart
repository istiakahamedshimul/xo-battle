import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../providers/providers.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class ResultScreen extends ConsumerWidget {
  final RoomModel room;
  final String uid;

  const ResultScreen({super.key, required this.room, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWinner = room.winner == uid;
    final isDraw = room.result == 'draw';
    final isAbandoned = room.result == 'abandoned';

    String resultText;
    int pointsGained;
    Color resultColor;
    String emoji;

    if (isDraw) {
      resultText = "It's a Draw!";
      pointsGained = 1;
      resultColor = Colors.orange;
      emoji = '🤝';
    } else if (isWinner) {
      resultText = isAbandoned ? 'Opponent Left!' : 'You Win!';
      pointsGained = isAbandoned ? 2 : 3;
      resultColor = Colors.green;
      emoji = '🏆';
    } else {
      resultText = 'You Lose!';
      pointsGained = 0;
      resultColor = Colors.red;
      emoji = '😔';
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              Text(resultText, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: resultColor)),
              const SizedBox(height: 12),
              if (pointsGained > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
                  child: Text('+$pointsGained points', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _rematch(context, ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rematch', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rematch(BuildContext context, WidgetRef ref) async {
    final guestId = uid == room.playerX ? room.playerO : room.playerX;
    final newRoom = await ref.read(roomServiceProvider).rematch(room.roomId, uid, guestId);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LobbyScreen(roomId: newRoom.roomId)),
        (_) => false,
      );
    }
  }
}
