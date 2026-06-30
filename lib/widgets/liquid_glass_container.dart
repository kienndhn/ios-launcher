import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// A drop-in replacement for our previous glassmorphism container that now
/// uses the real [liquid_glass_renderer] package with GPU-accelerated shaders.
///
/// Usage is identical to before:
/// ```dart
/// LiquidGlassContainer(
///   borderRadius: 24,
///   padding: EdgeInsets.all(16),
///   child: Text('Hello'),
/// )
/// ```
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// Optional tint color. Alpha channel controls the intensity of the tint.
  /// Defaults to a subtle white tint (0x22FFFFFF for dark, 0x18FFFFFF for light).
  final Color? glassColor;

  /// How much the glass refracts background pixels (higher = more distortion).
  final double thickness;

  /// Background blur radius (0 = no blur).
  final double blur;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(16),
    this.glassColor,
    this.thickness = 12,
    this.blur = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveGlassColor =
        glassColor ??
        (isDarkMode ? const Color(0x0EFFFFFF) : const Color(0x0AFFFFFF));

    return LiquidGlass.withOwnLayer(
      settings: LiquidGlassSettings(
        thickness: thickness,
        blur: blur,
        glassColor: effectiveGlassColor,
        lightIntensity: 0.6,
        ambientStrength: 0.15,
        saturation: 1.3,
        chromaticAberration: 0.008,
      ),
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Animated variant — now fully powered by the real liquid glass shader.
/// The package itself handles all animation/rendering; no AnimationController needed.
class AnimatedLiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? glassColor;
  final double thickness;
  final double blur;

  const AnimatedLiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(16),
    this.glassColor,
    this.thickness = 18,
    this.blur = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Delegate to LiquidGlassContainer — the shader already provides the
    // refraction/caustic animation inherently.
    return LiquidGlassContainer(
      borderRadius: borderRadius,
      padding: padding,
      glassColor: glassColor,
      thickness: thickness,
      blur: blur,
      child: child,
    );
  }
}

// Legacy painter stub — kept so any file still importing it won't break.
// It is a no-op now that the real package handles rendering.
class LiquidGlassHighlightPainter extends CustomPainter {
  final Color color;
  const LiquidGlassHighlightPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
