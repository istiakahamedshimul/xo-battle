import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/providers.dart';
import '../models/chat_message.dart';
import '../services/bot_service.dart';
import '../widgets/game_ui.dart';
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
  int _lastMoveCount = -1;
  bool _navigating = false;
  final BotService _botService = BotService();
  bool _botStarted = false;

  // Chat overlay
  final List<_OverlayMsg> _overlayMsgs = [];
  String? _lastSeenMsgId;

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

  void _onNewMessage(ChatMessage msg) {
    final id = '${msg.senderId}_${msg.createdAt.millisecondsSinceEpoch}';
    if (id == _lastSeenMsgId) return;
    _lastSeenMsgId = id;
    final overlay = _OverlayMsg(message: msg);
    setState(() => _overlayMsgs.add(overlay));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _overlayMsgs.remove(overlay));
    });
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

        if (room.moveCount != _lastMoveCount) {
          _lastMoveCount = room.moveCount;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer());
        }

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

        return GameShell(
          appBar: AppBar(
            title: const Text('XO Battle'),
            actions: [
              TextButton(
                onPressed: () => _leave(context, uid),
                child: const Text('Leave', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Main game column
              Column(
                children: [
                  _ScoreBar(uid: uid, opponentId: opponentId, isMyTurn: isMyTurn, mySymbol: mySymbol, timeLeft: timeLeft),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _Board(
                            board: room.board,
                            onTap: isMyTurn
                                ? (i) => _makeMove(i, uid, mySymbol,
                                    room.currentTurn == room.playerX ? room.playerO : room.playerX,
                                    room.board)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Chat quick-send bar (only for real players)
                  if (!room.isVsBot)
                    _ChatBar(
                      roomId: widget.roomId,
                      uid: uid,
                      onNewMessage: _onNewMessage,
                    ),
                ],
              ),
              // Floating message overlay
              if (_overlayMsgs.isNotEmpty)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Column(
                      children: _overlayMsgs.map((m) => _FloatingBubble(msg: m, myUid: uid)).toList(),
                    ),
                  ),
                ),
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

// ── Chat bar ────────────────────────────────────────────────────────────────

class _ChatBar extends ConsumerStatefulWidget {
  final String roomId;
  final String uid;
  final void Function(ChatMessage) onNewMessage;
  const _ChatBar({required this.roomId, required this.uid, required this.onNewMessage});

  @override
  ConsumerState<_ChatBar> createState() => _ChatBarState();
}

class _ChatBarState extends ConsumerState<_ChatBar> {
  static const _presets = ['👍', '🔥', '😂', '😮', 'GG!', 'Nooo!', 'Nice!', 'Lucky!'];
  String? _lastId;

  @override
  Widget build(BuildContext context) {
    // Listen for incoming messages to trigger overlay
    ref.listen(chatStreamProvider(widget.roomId), (_, next) {
      next.whenData((msgs) {
        if (msgs.isEmpty) return;
        final latest = msgs.last;
        final id = '${latest.senderId}_${latest.createdAt.millisecondsSinceEpoch}';
        if (id != _lastId && latest.senderId != widget.uid) {
          _lastId = id;
          widget.onNewMessage(latest);
        }
      });
    });

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        border: Border(top: BorderSide(color: GameColors.violet.withOpacity(0.15))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _presets.map((p) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(p, style: const TextStyle(fontSize: 16)),
              onPressed: () => _send(p),
              backgroundColor: GameColors.violet.withOpacity(0.10),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _send(String msg) async {
    final chat = ChatMessage(
      senderId: widget.uid,
      message: msg,
      type: RegExp(r'[\u{1F300}-\u{1FFFF}]', unicode: true).hasMatch(msg) ? 'emoji' : 'text',
      createdAt: DateTime.now(),
    );
    await ref.read(roomServiceProvider).sendMessage(widget.roomId, chat);
    // Show own message in overlay too
    widget.onNewMessage(chat);
  }
}

// ── Floating bubble overlay ──────────────────────────────────────────────────

class _OverlayMsg {
  final ChatMessage message;
  _OverlayMsg({required this.message});
}

class _FloatingBubble extends StatefulWidget {
  final _OverlayMsg msg;
  final String myUid;
  const _FloatingBubble({required this.msg, required this.myUid});

  @override
  State<_FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<_FloatingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    // Start fade out after 2.2s
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.msg.message.senderId == widget.myUid;
    final color = isMe ? GameColors.violet : GameColors.cyan;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              left: isMe ? 60 : 16,
              right: isMe ? 16 : 60,
              bottom: 6,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.92),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Text(
              widget.msg.message.message,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Board ────────────────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  final List<String> board;
  final void Function(int)? onTap;
  const _Board({required this.board, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: 9,
        itemBuilder: (_, i) {
          final cell = board[i];
          final color = cell == 'X' ? GameColors.violet : GameColors.cyan;
          return GestureDetector(
            onTap: cell.isEmpty && onTap != null ? () => onTap!(i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: cell.isEmpty ? Theme.of(context).colorScheme.surface : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cell.isEmpty ? Colors.black12 : color.withOpacity(0.45), width: 2),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    cell,
                    key: ValueKey(cell + i.toString()),
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Score bar ────────────────────────────────────────────────────────────────

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

    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _PlayerChip(userAsync: me, symbol: mySymbol, active: isMyTurn),
          const Spacer(),
          Column(
            children: [
              Text('$timeLeft',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: timeLeft <= 5 ? GameColors.rose : GameColors.violet)),
              Text(isMyTurn ? 'Your turn' : 'Wait...',
                  style: TextStyle(fontSize: 12, color: isMyTurn ? Colors.green : Colors.grey)),
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
    final color = symbol == 'X' ? GameColors.violet : GameColors.cyan;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
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
