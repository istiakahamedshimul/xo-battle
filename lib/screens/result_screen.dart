import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';
import '../providers/providers.dart';
import '../widgets/game_ui.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final String uid;

  const ResultScreen({super.key, required this.room, required this.uid});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.room.roomId));

    return roomAsync.when(
      loading: () => _buildResult(context, widget.room),
      error: (_, __) => _buildResult(context, widget.room),
      data: (room) {
        final live = room ?? widget.room;

        // Both accepted — rematchRoomId is set — navigate simultaneously
        if (live.rematchRoomId != null && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LobbyScreen(roomId: live.rematchRoomId!)),
                (_) => false,
              );
            }
          });
        }

        // Opponent requested rematch — show dialog to me
        if (live.rematchRequestBy != null &&
            live.rematchRequestBy != widget.uid &&
            live.rematchRoomId == null &&
            !_navigating) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showRematchDialog(context, live));
        }

        return _buildResult(context, live);
      },
    );
  }

  Widget _buildResult(BuildContext context, RoomModel room) {
    final isWinner = room.winner == widget.uid;
    final isDraw = room.result == 'draw';
    final isAbandoned = room.result == 'abandoned';

    final String resultText;
    final int pointsGained;
    final Color resultColor;
    final String emoji;

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

    final iRequested = room.rematchRequestBy == widget.uid;
    final opponentRequested = room.rematchRequestBy != null && room.rematchRequestBy != widget.uid;

    return GameShell(
      child: Center(
        child: GamePanel(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(resultText, textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: resultColor)),
              const SizedBox(height: 12),
              if (pointsGained > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: GameColors.amber.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                  child: Text('+$pointsGained points', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GameColors.amber)),
                ),
              const SizedBox(height: 48),
              // Rematch button states
              if (iRequested)
                _RematchWaiting()
              else if (opponentRequested)
                const SizedBox() // dialog handles this
              else
                GameButton(
                    icon: Icons.refresh,
                    label: 'Rematch',
                    onPressed: () => _requestRematch(room),
                  ),
              const SizedBox(height: 12),
              GameButton(
                icon: Icons.home,
                label: 'Back to Home',
                outlined: true,
                onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestRematch(RoomModel room) async {
    await ref.read(roomServiceProvider).requestRematch(room.roomId, widget.uid);
    setState(() {});
  }

  Future<void> _showRematchDialog(BuildContext context, RoomModel room) async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Rematch Request'),
        content: const Text('Your opponent wants a rematch. Accept?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      await ref.read(roomServiceProvider).acceptRematch(room.roomId, room.playerX, room.playerO);
      // navigation handled by stream (rematchRoomId will be set)
    } else if (mounted) {
      // Declined — clear the request so requester sees it was declined
      await ref.read(roomServiceProvider).declineRematch(room.roomId);
    }
  }
}

class _RematchWaiting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: GameColors.violet.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GameColors.violet.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Waiting for opponent...', style: TextStyle(fontSize: 16, color: GameColors.violet, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
