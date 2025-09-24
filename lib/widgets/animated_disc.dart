import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AnimatedDisc extends StatefulWidget {
  final bool isPlaying;

  const AnimatedDisc({super.key, required this.isPlaying});

  @override
  State<AnimatedDisc> createState() => _AnimatedDiscState();
}

class _AnimatedDiscState extends State<AnimatedDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * 3.14159,
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.discGradient,
              boxShadow: [
                BoxShadow(
                  color: Color(0x4D6366F1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                ),
                child: const Icon(
                  Icons.radio,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
