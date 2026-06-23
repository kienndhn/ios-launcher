import 'package:flutter/material.dart';

class WiggleWrapper extends StatefulWidget {
  final Widget child;
  final bool isWiggling;

  const WiggleWrapper({
    super.key,
    required this.child,
    required this.isWiggling,
  });

  @override
  State<WiggleWrapper> createState() => _WiggleWrapperState();
}

class _WiggleWrapperState extends State<WiggleWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    if (widget.isWiggling) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant WiggleWrapper oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);

    if (widget.isWiggling && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isWiggling && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = (widget.isWiggling)
            ? (0.015 * (0.5 - _controller.value))
            : 0.0;
        final dy = (widget.isWiggling)
            ? (0.8 * (0.5 - _controller.value).abs())
            : 0.0;

        return Transform(
          transform: Matrix4.identity()
            ..rotateZ(angle)
            ..translate(0.0, dy, 0.0),
          alignment: Alignment.center,
          child: widget.child,
        );
      },
    );
  }
}
