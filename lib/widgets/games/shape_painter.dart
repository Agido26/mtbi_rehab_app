import 'package:flutter/material.dart';
import '../../models/shape_match_config.dart';
import 'dart:math' as math;

class ShapePainter extends CustomPainter {
  final ShapeType type;
  final Color color;
  final bool isShadow;
  final double strokeWidth;

  ShapePainter({
    required this.type,
    required this.color,
    this.isShadow = false,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isShadow ? Colors.black38 : color
      ..style = isShadow ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    switch (type) {
      case ShapeType.circle:
        canvas.drawCircle(center, radius * 0.8, paint);
        break;
      case ShapeType.square:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 1.6,
          height: radius * 1.6,
        );
        canvas.drawRect(rect, paint);
        break;
      case ShapeType.triangle:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 0.8)
          ..lineTo(center.dx + radius * 0.8, center.dy + radius * 0.6)
          ..lineTo(center.dx - radius * 0.8, center.dy + radius * 0.6)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.star:
        _drawStar(canvas, center, radius * 0.8, paint);
        break;
      case ShapeType.diamond:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius * 0.8)
          ..lineTo(center.dx + radius * 0.6, center.dy)
          ..lineTo(center.dx, center.dy + radius * 0.8)
          ..lineTo(center.dx - radius * 0.6, center.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case ShapeType.hexagon:
        _drawHexagon(canvas, center, radius * 0.7, paint);
        break;
      case ShapeType.heart:
        _drawHeart(canvas, center, radius * 0.7, paint);
        break;
      case ShapeType.cross:
        _drawCross(canvas, center, radius * 0.7, paint);
        break;
      case ShapeType.moon:
        _drawMoon(canvas, center, radius * 0.7, paint);
        break;
      case ShapeType.arrow:
        _drawArrow(canvas, center, radius * 0.7, paint);
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.4;
      final angle = (i * 3.14159 / points) - 3.14159 / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 3.14159 / 3) - 3.14159 / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final width = size;
    final height = size;

    path.moveTo(center.dx, center.dy + height * 0.3);
    path.cubicTo(
      center.dx,
      center.dy,
      center.dx - width * 0.5,
      center.dy - height * 0.3,
      center.dx - width * 0.5,
      center.dy,
    );
    path.cubicTo(
      center.dx - width * 0.5,
      center.dy + height * 0.3,
      center.dx,
      center.dy + height * 0.6,
      center.dx,
      center.dy + height * 0.6,
    );
    path.cubicTo(
      center.dx,
      center.dy + height * 0.6,
      center.dx + width * 0.5,
      center.dy + height * 0.3,
      center.dx + width * 0.5,
      center.dy,
    );
    path.cubicTo(
      center.dx + width * 0.5,
      center.dy - height * 0.3,
      center.dx,
      center.dy,
      center.dx,
      center.dy + height * 0.3,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCross(Canvas canvas, Offset center, double size, Paint paint) {
    final thickness = size * 0.25;
    final length = size * 0.8;

    // Horizontal bar
    final hRect = Rect.fromCenter(
      center: center,
      width: length * 2,
      height: thickness * 2,
    );
    canvas.drawRect(hRect, paint);

    // Vertical bar
    final vRect = Rect.fromCenter(
      center: center,
      width: thickness * 2,
      height: length * 2,
    );
    canvas.drawRect(vRect, paint);
  }

  void _drawMoon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..addArc(
        Rect.fromCenter(center: center, width: size * 2, height: size * 2),
        -3.14159 * 0.8,
        3.14159 * 1.6,
      );

    final innerPath = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(center.dx + size * 0.3, center.dy),
          width: size * 1.6,
          height: size * 1.6,
        ),
        -3.14159 * 0.5,
        3.14159,
      );

    final crescent = Path.combine(PathOperation.difference, path, innerPath);
    canvas.drawPath(crescent, paint);
  }

  void _drawArrow(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.6, center.dy)
      ..lineTo(center.dx + size * 0.2, center.dy)
      ..lineTo(center.dx + size * 0.2, center.dy + size * 0.8)
      ..lineTo(center.dx - size * 0.2, center.dy + size * 0.8)
      ..lineTo(center.dx - size * 0.2, center.dy)
      ..lineTo(center.dx - size * 0.6, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
