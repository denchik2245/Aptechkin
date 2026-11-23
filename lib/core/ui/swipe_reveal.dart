import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:flutter/material.dart';

/// Figma «swipe action» (853:11697): 52 pt circle and a caption.
class SwipeActionButton extends StatelessWidget {
  const SwipeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.width = 64,
    super.key,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// 64 in a swipe; `null` lets the caption take its natural width
  /// (actions under the package hero).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: destructive ? palette.fail : palette.surfaceCard,
                  shape: BoxShape.circle,
                ),
                // Ink icons follow the theme; the delete icon stays white.
                child: DesignIcon(
                  icon,
                  size: 24,
                  color: destructive ? null : palette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: AppTypography.labelMedium.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal swipe that slides [child] left and reveals [actions]
/// (Figma «Аптечки / Свайп» 671:1631: card offset 144, actions 12 pt
/// from the card and aligned to the right page padding).
class SwipeReveal extends StatefulWidget {
  const SwipeReveal({
    required this.child,
    required this.actions,
    required this.open,
    required this.onOpenChanged,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final List<Widget> actions;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final bool enabled;

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.open ? 1 : 0,
  );

  double get _extent => widget.actions.length * 64.0 +
      (widget.actions.length - 1) * 4 +
      12;

  @override
  void didUpdateWidget(SwipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        _controller.value -= details.primaryDelta! / _extent;
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final open = velocity < -300 || (velocity <= 300 && _controller.value > 0.5);
        open ? _controller.forward() : _controller.reverse();
        if (open != widget.open) widget.onOpenChanged(open);
      },
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              // Closed actions are not built, so they stay out of semantics.
              builder: (context, child) => _controller.value == 0
                  ? const SizedBox.shrink()
                  : Opacity(opacity: _controller.value, child: child),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      widget.actions[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_controller.value * _extent, 0),
              child: child,
            ),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
