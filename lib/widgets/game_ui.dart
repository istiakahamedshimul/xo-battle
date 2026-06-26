import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameColors {
  static const ink = Color(0xFF101327);
  static const panel = Color(0xFFFFFFFF);
  static const panelDark = Color(0xFF191D35);
  static const violet = Color(0xFF7C3AED);
  static const cyan = Color(0xFF06B6D4);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFE11D48);
  static const green = Color(0xFF16A34A);
  static const muted = Color(0xFF6B7280);
}

class GameShell extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  const GameShell({
    super.key,
    required this.child,
    this.appBar,
    this.padding = const EdgeInsets.all(20),
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: appBar,
      body: Stack(
        children: [
          const Positioned.fill(child: _GameBackdrop()),
          SafeArea(
            child: scrollable
                ? SingleChildScrollView(child: content)
                : content,
          ),
        ],
      ),
    );
  }
}

class GamePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (dark ? GameColors.panelDark.withOpacity(0.92) : Colors.white.withOpacity(0.94)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(dark ? 0.12 : 0.65)),
        boxShadow: [
          BoxShadow(
            color: GameColors.violet.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class XoLogo extends StatelessWidget {
  final double size;
  final bool compact;

  const XoLogo({super.key, this.size = 88, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [GameColors.violet, GameColors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: GameColors.cyan.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 12)),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MiniBoardPainter())),
              Center(
                child: Text(
                  'XO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 14),
          const Text(
            'XO BATTLE',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Fast duels. Clean wins.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62), fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class GameButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final Widget? trailing;

  const GameButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = GameColors.violet,
    this.outlined = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final radius = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.65), width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            shape: radius,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.45),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          elevation: 0,
          shape: radius,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        child: child,
      ),
    );
  }
}

class GameStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const GameStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.62))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.56),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _GameBackdrop extends StatelessWidget {
  const _GameBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF0B1023), Color(0xFF172033), Color(0xFF111827)]
              : const [Color(0xFFF8FBFF), Color(0xFFEFF6FF), Color(0xFFFFFBEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _BackdropPainter(dark: dark)),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final bool dark;
  const _BackdropPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (dark ? Colors.white : GameColors.ink).withOpacity(0.045);
    const gap = 36.0;
    for (double x = -gap; x < size.width + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.24, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width * 0.12), paint);
    }

    final markPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final marks = [
      (Offset(size.width * 0.12, size.height * 0.16), 'x', GameColors.violet),
      (Offset(size.width * 0.82, size.height * 0.20), 'o', GameColors.cyan),
      (Offset(size.width * 0.18, size.height * 0.78), 'o', GameColors.amber),
      (Offset(size.width * 0.86, size.height * 0.72), 'x', GameColors.rose),
    ];
    for (final mark in marks) {
      markPaint.color = mark.$3.withOpacity(dark ? 0.18 : 0.14);
      if (mark.$2 == 'x') {
        canvas.drawLine(mark.$1 + const Offset(-14, -14), mark.$1 + const Offset(14, 14), markPaint);
        canvas.drawLine(mark.$1 + const Offset(14, -14), mark.$1 + const Offset(-14, 14), markPaint);
      } else {
        canvas.drawCircle(mark.$1, 16, markPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => oldDelegate.dark != dark;
}

class _MiniBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = math.max(1, size.width * 0.025)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width / 3, size.height * 0.18), Offset(size.width / 3, size.height * 0.82), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, size.height * 0.18), Offset(size.width * 2 / 3, size.height * 0.82), paint);
    canvas.drawLine(Offset(size.width * 0.18, size.height / 3), Offset(size.width * 0.82, size.height / 3), paint);
    canvas.drawLine(Offset(size.width * 0.18, size.height * 2 / 3), Offset(size.width * 0.82, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
