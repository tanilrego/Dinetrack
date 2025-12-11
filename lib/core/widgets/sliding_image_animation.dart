import 'package:flutter/material.dart';

class SlidingImageAnimation extends StatefulWidget {
  final String imagePath;
  final double height;
  final Duration duration;

  const SlidingImageAnimation({
    super.key,
    required this.imagePath,
    this.height = 550,
    this.duration = const Duration(seconds: 20),
  });

  @override
  State<SlidingImageAnimation> createState() => _SlidingImageAnimationState();
}

class _SlidingImageAnimationState extends State<SlidingImageAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true); // Move back and forth
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background gradient/placeholder
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    const Color(0xFF10B981).withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            // Animated Image
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Calculate alignment to pan from -1.0 (left) to 1.0 (right)
                // However, for a "pan" effect where the image is larger than the container,
                // we usually use Alignment.
                // Alignment(-1, 0) is left edge, Alignment(1, 0) is right edge.
                // We'll vary the x-alignment.
                return FractionallySizedBox(
                  widthFactor:
                      1.2, // Make image wider than container so it can scroll
                  heightFactor: 1.2, // Make slightly taller too for zoom effect
                  alignment: Alignment(_controller.value * 2 - 1, 0),
                  child: child,
                );
              },
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.restaurant, size: 80, color: Colors.grey),
                  );
                },
              ),
            ),
            // Overlay gradient for better text readability (optional, but requested "beautiful ui")
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
