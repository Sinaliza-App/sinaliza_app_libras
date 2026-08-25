import 'package:flutter/material.dart';

class NeonPulse extends StatefulWidget {
  final Widget child;
  final Color neonColor;
  final double blurRadius;
  final double spreadRadius;

  const NeonPulse({
    super.key,
    required this.child,
    required this.neonColor,
    this.blurRadius = 15.0,
    this.spreadRadius = 2.0,
  });

  @override
  State<NeonPulse> createState() => _NeonPulseState();
}

class _NeonPulseState extends State<NeonPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.neonColor.withValues(alpha: 0.5 * _animation.value),
                blurRadius: widget.blurRadius * _animation.value,
                spreadRadius: widget.spreadRadius * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
