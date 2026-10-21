import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'carrom_physics.dart';

class AimLinesPainter extends CustomPainter {
  final Offset strikerPos;
  final Offset aimDir;
  final List<Offset> coins;
  final List<CoinType> coinTypes;
  final double boardSize;
  final double strikerRadius;
  final double coinRadius;
  final double cushionInset;
  final bool showCushionReflection;
  final bool showCoinDeflection;
  final bool drawBoardBackground;

  AimLinesPainter({
    required this.strikerPos,
    required this.aimDir,
    required this.coins,
    required this.coinTypes,
    required this.boardSize,
    this.strikerRadius = 18.0,
    this.coinRadius = 14.0,
    this.cushionInset = 28.0,
    this.showCushionReflection = true,
    this.showCoinDeflection = true,
    this.drawBoardBackground = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / boardSize;
    canvas.save();
    canvas.scale(scale, scale);

    if (drawBoardBackground) {
      _drawBoard(canvas);
    }

    final sim = CarromPhysics.simulateTrajectory(
      strikerPos: strikerPos,
      aimDir: aimDir,
      coins: coins,
      boardSize: boardSize,
      strikerRadius: strikerRadius,
      coinRadius: coinRadius,
      cushionInset: cushionInset,
      maxBounces: showCushionReflection ? 3 : 0,
    );

    // 1. Draw Striker Trajectory (Neon Cyan / Electric Blue with glow)
    _drawPathWithGlow(
      canvas: canvas,
      points: sim.strikerPath,
      lineColor: const Color(0xFF00E5FF),
      glowColor: const Color(0x6600E5FF),
      strokeWidth: 3.5,
      isDashed: false,
    );

    // 2. Draw Ghost Striker at impact point
    if (sim.hitCoinIndex != null && sim.strikerPath.length >= 2) {
      final impactPoint = sim.strikerPath.last;
      final ghostPaint = Paint()
        ..color = const Color(0x5500E5FF)
        ..style = PaintingStyle.fill;
      final ghostBorder = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(impactPoint, strikerRadius, ghostPaint);
      canvas.drawCircle(impactPoint, strikerRadius, ghostBorder);
    }

    // 3. Draw Target Coin Trajectory (Neon Orange / Amber / Golden with glow)
    if (showCoinDeflection && sim.coinPath.length >= 2) {
      final isTargetingPocket = sim.targetedPocketIndex != null;
      final coinLineColor = isTargetingPocket ? const Color(0xFF00E676) : const Color(0xFFFF9100);
      final coinGlowColor = isTargetingPocket ? const Color(0x6600E676) : const Color(0x66FF9100);

      _drawPathWithGlow(
        canvas: canvas,
        points: sim.coinPath,
        lineColor: coinLineColor,
        glowColor: coinGlowColor,
        strokeWidth: 3.5,
        isDashed: true,
      );

      // Draw arrow head at the end of coin trajectory
      _drawArrowHead(
        canvas: canvas,
        start: sim.coinPath[sim.coinPath.length - 2],
        end: sim.coinPath.last,
        color: coinLineColor,
      );
    }

    // 4. Highlight pockets if coin is heading towards them
    final pockets = CarromPhysics.getPocketPositions(boardSize, cushionInset);
    for (int i = 0; i < pockets.length; i++) {
      final pocketPos = pockets[i];
      final isTargeted = sim.targetedPocketIndex == i;
      final pocketPaint = Paint()
        ..color = isTargeted ? const Color(0xFF00E676) : Colors.black87
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = isTargeted ? Colors.white : const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isTargeted ? 3.0 : 1.5;

      canvas.drawCircle(pocketPos, 18.0, pocketPaint);
      canvas.drawCircle(pocketPos, 18.0, borderPaint);

      if (isTargeted) {
        // Pulsing ring for targeted pocket
        final pulsePaint = Paint()
          ..color = const Color(0x5500E676)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        canvas.drawCircle(pocketPos, 24.0, pulsePaint);
      }
    }

    // 5. Draw Coins
    for (int i = 0; i < coins.length; i++) {
      final isHit = sim.hitCoinIndex == i;
      _drawCoin(canvas, coins[i], coinTypes[i], isHit);
    }

    // 6. Draw Striker
    _drawStriker(canvas, strikerPos);

    canvas.restore();
  }

  void _drawBoard(Canvas canvas) {
    // Board surface
    final boardRect = Rect.fromLTWH(0, 0, boardSize, boardSize);
    final boardPaint = Paint()..color = const Color(0xFFE2C9A5);
    canvas.drawRect(boardRect, boardPaint);

    // Cushion border
    final cushionPaint = Paint()
      ..color = const Color(0xFF4E2C1D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cushionInset * 2;
    canvas.drawRect(boardRect, cushionPaint);

    // Center circle
    final center = Offset(boardSize / 2, boardSize / 2);
    final centerCirclePaint = Paint()
      ..color = const Color(0x44D32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 38.0, centerCirclePaint);
    canvas.drawCircle(center, 10.0, Paint()..color = const Color(0x66D32F2F));

    // Baseline guidelines
    final baselinePaint = Paint()
      ..color = const Color(0x44000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final lineMargin = cushionInset + 40.0;
    canvas.drawLine(
      Offset(lineMargin, boardSize - lineMargin),
      Offset(boardSize - lineMargin, boardSize - lineMargin),
      baselinePaint,
    );
  }

  void _drawStriker(Canvas canvas, Offset pos) {
    // Outer shadow / glow
    final glowPaint = Paint()
      ..color = const Color(0x6600E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(pos, strikerRadius + 2, glowPaint);

    // Body
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE0F7FA), Color(0xFF00B0FF), Color(0xFF0077C2)],
      ).createShader(Rect.fromCircle(center: pos, radius: strikerRadius));
    canvas.drawCircle(pos, strikerRadius, bodyPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(pos, strikerRadius, borderPaint);

    // Inner detail
    canvas.drawCircle(pos, strikerRadius * 0.45, borderPaint..strokeWidth = 1.5);
  }

  void _drawCoin(Canvas canvas, Offset pos, CoinType type, bool isHit) {
    Color primaryColor;
    Color secondaryColor;
    Color borderColor;

    switch (type) {
      case CoinType.white:
        primaryColor = const Color(0xFFFFFDD0);
        secondaryColor = const Color(0xFFD7CCC8);
        borderColor = Colors.black87;
        break;
      case CoinType.black:
        primaryColor = const Color(0xFF263238);
        secondaryColor = const Color(0xFF000000);
        borderColor = Colors.amber.shade200;
        break;
      case CoinType.queen:
        primaryColor = const Color(0xFFFF1744);
        secondaryColor = const Color(0xFFB71C1C);
        borderColor = Colors.amber;
        break;
    }

    if (isHit) {
      // Glow on hit coin
      final hitGlow = Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(pos, coinRadius + 4, hitGlow);
    }

    final coinPaint = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, secondaryColor],
      ).createShader(Rect.fromCircle(center: pos, radius: coinRadius));
    canvas.drawCircle(pos, coinRadius, coinPaint);

    final border = Paint()
      ..color = isHit ? const Color(0xFFFFEB3B) : borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHit ? 2.5 : 1.5;
    canvas.drawCircle(pos, coinRadius, border);
    canvas.drawCircle(pos, coinRadius * 0.4, border..strokeWidth = 1.0);
  }

  void _drawPathWithGlow({
    required Canvas canvas,
    required List<Offset> points,
    required Color lineColor,
    required Color glowColor,
    required double strokeWidth,
    required bool isDashed,
  }) {
    if (points.length < 2) return;

    final glowPaint = Paint()
      ..color = glowColor
      ..strokeWidth = strokeWidth + 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final corePaint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      if (isDashed) {
        _drawDashedLine(canvas, p1, p2, glowPaint, 8, 5);
        _drawDashedLine(canvas, p1, p2, corePaint, 8, 5);
      } else {
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, corePaint);
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final unitX = dx / distance;
    final unitY = dy / distance;

    double currentDist = 0.0;
    while (currentDist < distance) {
      final start = Offset(p1.dx + unitX * currentDist, p1.dy + unitY * currentDist);
      final segmentEndDist = math.min(currentDist + dashWidth, distance);
      final end = Offset(p1.dx + unitX * segmentEndDist, p1.dy + unitY * segmentEndDist);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  void _drawArrowHead({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required Color color,
  }) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowLength = 14.0;
    const arrowAngle = math.pi / 6;

    final p1 = Offset(
      end.dx - arrowLength * math.cos(angle - arrowAngle),
      end.dy - arrowLength * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      end.dx - arrowLength * math.cos(angle + arrowAngle),
      end.dy - arrowLength * math.sin(angle + arrowAngle),
    );

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AimLinesPainter oldDelegate) {
    return oldDelegate.strikerPos != strikerPos ||
        oldDelegate.aimDir != aimDir ||
        oldDelegate.coins != coins ||
        oldDelegate.showCushionReflection != showCushionReflection ||
        oldDelegate.showCoinDeflection != showCoinDeflection ||
        oldDelegate.drawBoardBackground != drawBoardBackground;
  }
}
