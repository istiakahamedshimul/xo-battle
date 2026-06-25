import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../models/chat_message.dart';
import '../services/bot_service.dart';
import 'result_screen.dart';
import 'home_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _timer;
  bool _chatOpen = false;
  int _lastMoveCount = -1;
  bool _navigating = false;
  final BotService _botService = BotService();
  bool _botStarted = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    ref.read(timerProvider.notifier).reset();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(timerProvider.notifier).tick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _botService.stopBotEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final timeLeft = ref.watch(timerProvider);

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) return const Scaffold(body: Center(child: Text('Room not found')));

        // Reset timer whenever a new move is made by either player
        if (room.moveCount != _lastMoveCount) {
          _lastMoveCount = room.moveCount;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }

        // Start bot engine once when room is playing vs bot
        if (room.isVsBot && room.isPlaying && !_botStarted && room.botUid != null) {
          _botStarted = true;
          final botProfile = BotService.botProfiles.firstWhere(
            (b) => b.uid == room.botUid,
            orElse: () => BotService.botProfiles.first,
          );
          final botSymbol = room.playerX == room.botUid ? 'X' : 'O';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _botService.startBotEngine(widget.roomId, room.botUid!, botSymbol, botProfile.difficulty);
          });
        }

        if (room.isFinished && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _timer?.cancel();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(room: room, uid: uid)));
          });
        }

        final mySymbol = room.playerX == uid ? 'X' : 'O';
        final isMyTurn = room.currentTurn == uid;
        final opponentId = uid == room.playerX ? room.playerO : room.playerX;

        return Scaffold(
          appBar: AppBar(
            title: const Text('XO Battle'),
            actions: [
              if (!room.isVsBot)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => setState(() => _chatOpen = !_chatOpen),
                ),
              TextButton(
                onPressed: () => _leave(context, uid),
                child: const Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          body: Column(
            children: [
              _ScoreBar(uid: uid, opponentId: opponentId, isMyTurn: isMyTurn, mySymbol: mySymbol, timeLeft: timeLeft),
              const Divider(height: 1),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Board(
                        board: room.board,
                        onTap: isMyTurn
                            ? (i) => _makeMove(i, uid, mySymbol, room.currentTurn == room.playerX ? room.playerO : room.playerX, room.board)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              if (_chatOpen && !room.isVsBot) _ChatPanel(roomId: widget.roomId, uid: uid),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makeMove(int index, String uid, String symbol, String nextTurn, List<String> board) async {
    if (board[index].isNotEmpty) return;
    HapticFeedback.lightImpact();
    _startTimer();
    await ref.read(roomServiceProvider).makeMove(widget.roomId, index, uid, symbol, nextTurn);
  }

  Future<void> _leave(BuildContext context, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('Leaving will count as a loss.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(roomServiceProvider).abandonRoom(widget.roomId, uid);
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    }
  }
}

class _Board extends StatelessWidget {
  final List<String> board;
  final void Function(int)? onTap;

  const _Board({required this.board, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: 9,
      itemBuilder: (_, i) {
        final cell = board[i];
        return GestureDetector(
          onTap: cell.isEmpty && onTap != null ? () => onTap!(i) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cell.isEmpty ? Colors.grey.shade100 : (cell == 'X' ? Colors.deepPurple.shade50 : Colors.teal.shade50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  cell,
                  key: ValueKey(cell + i.toString()),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: cell == 'X' ? Colors.deepPurple : Colors.teal,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreBar extends ConsumerWidget {
  final String uid;
  final String opponentId;
  final bool isMyTurn;
  final String mySymbol;
  final int timeLeft;

  const _ScoreBar({required this.uid, required this.opponentId, required this.isMyTurn, required this.mySymbol, required this.timeLeft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(userProfileProvider(uid));
    final opp = ref.watch(userProfileProvider(opponentId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _PlayerChip(userAsync: me, symbol: mySymbol, active: isMyTurn),
          const Spacer(),
          Column(
            children: [
              Text('$timeLeft', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: timeLeft <= 5 ? Colors.red : Colors.black)),
              Text(isMyTurn ? 'Your turn' : 'Wait...', style: TextStyle(fontSize: 12, color: isMyTurn ? Colors.green : Colors.grey)),
            ],
          ),
          const Spacer(),
          _PlayerChip(userAsync: opp, symbol: mySymbol == 'X' ? 'O' : 'X', active: !isMyTurn),
        ],
      ),
    );
  }
}

class _PlayerChip extends ConsumerWidget {
  final AsyncValue userAsync;
  final String symbol;
  final bool active;

  const _PlayerChip({required this.userAsync, required this.symbol, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = symbol == 'X' ? Colors.deepPurple : Colors.teal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : Colors.transparent, width: 2),
      ),
      child: Column(
        children: [
          Text(symbol, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          userAsync.when(
            data: (u) => Text((u as dynamic)?.name ?? 'Player', style: const TextStyle(fontSize: 12)),
            loading: () => const Text('...'),
            error: (_, __) => const Text('Player'),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends ConsumerStatefulWidget {
  final String roomId;
  final String uid;
  const _ChatPanel({required this.roomId, required this.uid});

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  static const _presets = ['Good luck!', 'Nice move!', '😂', '😮', '👍', '🔥', 'Well played!', 'Nooo!'];

  Future<void> _send(String msg) async {
    final chat = ChatMessage(senderId: widget.uid, message: msg, type: msg.length <= 2 ? 'emoji' : 'text', createdAt: DateTime.now());
    await ref.read(roomServiceProvider).sendMessage(widget.roomId, chat);
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatStreamProvider(widget.roomId));

    return Container(
      height: 200,
      color: Colors.grey.shade50,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: chats.when(
              data: (msgs) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[msgs.length - 1 - i];
                  final isMe = m.senderId == widget.uid;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.deepPurple.shade100 : Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.message),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: _presets
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(p), onPressed: () => _send(p)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
