import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CoinType {
  white,
  black,
  queen,
}

class CarromPhysics {
  // Standard carrom board dimension ratio: 1:1 square
  // Cushion bounce elasticity / restitution
  static const double cushionRestitution = 0.95;
  // Ball collision restitution
  static const double coinRestitution = 0.92;

  /// Given:
  /// - [strikerPos]: Starting position of striker
  /// - [aimDir]: Normalized direction vector of striker shot
  /// - [coins]: List of coin positions & types
  /// - [boardSize]: Dimension of the board square (width == height)
  /// - [strikerRadius]: Radius of striker in pixels
  /// - [coinRadius]: Radius of coins in pixels
  /// - [cushionInset]: Distance from outer boundary to cushion inner edge
  /// 
  /// Calculates:
  /// - Striker direct or cushion ray until it hits a coin or bounces up to maxBounces
  /// - Target coin trajectory after collision towards pocket or cushion
  static AimSimulationResult simulateTrajectory({
    required Offset strikerPos,
    required Offset aimDir,
    required List<Offset> coins,
    required double boardSize,
    required double strikerRadius,
    required double coinRadius,
    required double cushionInset,
    int maxBounces = 2,
  }) {
    List<Offset> strikerPath = [strikerPos];
    Offset currentOrigin = strikerPos;
    Offset currentDir = _normalize(aimDir);

    double minX = cushionInset + strikerRadius;
    double maxX = boardSize - cushionInset - strikerRadius;
    double minY = cushionInset + strikerRadius;
    double maxY = boardSize - cushionInset - strikerRadius;

    int? hitCoinIndex;
    Offset? collisionPoint;
    Offset? coinImpactPoint;
    Offset? coinDeflectionDir;
    Offset? strikerDeflectionDir;

    for (int bounce = 0; bounce <= maxBounces; bounce++) {
      // 1. Check if current ray intersects any coin before hitting cushion
      double nearestCoinDist = double.infinity;
      int nearestIndex = -1;
      Offset? nearestHitStrikerPos;

      for (int i = 0; i < coins.length; i++) {
        final coinPos = coins[i];
        final hit = _rayCircleIntersection(
          rayOrigin: currentOrigin,
          rayDir: currentDir,
          circleCenter: coinPos,
          combinedRadius: strikerRadius + coinRadius,
        );

        if (hit != null && hit.t > 0.001 && hit.t < nearestCoinDist) {
          nearestCoinDist = hit.t;
          nearestIndex = i;
          nearestHitStrikerPos = hit.point;
        }
      }

      // 2. Check collision with cushions
      final cushionHit = _rayCushionIntersection(
        origin: currentOrigin,
        dir: currentDir,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
      );

      if (nearestIndex != -1 && (cushionHit == null || nearestCoinDist < cushionHit.dist)) {
        // Hit coin!
        hitCoinIndex = nearestIndex;
        collisionPoint = nearestHitStrikerPos!;
        strikerPath.add(collisionPoint);

        // Physics deflection calculation
        final hitCoin = coins[hitCoinIndex];
        // Normal vector from coin to striker at impact point
        final normal = _normalize(hitCoin - collisionPoint);
        coinDeflectionDir = normal; // Coin travels along center-to-center line

        // Striker deflection: component perpendicular to line of impact or tangential
        final dot = currentDir.dx * normal.dx + currentDir.dy * normal.dy;
        final tangent = Offset(currentDir.dx - dot * normal.dx, currentDir.dy - dot * normal.dy);
        strikerDeflectionDir = _normalize(tangent);

        coinImpactPoint = hitCoin;
        break;
      } else if (cushionHit != null && bounce < maxBounces) {
        // Hit cushion, bounce!
        strikerPath.add(cushionHit.hitPoint);
        currentOrigin = cushionHit.hitPoint;
        currentDir = cushionHit.newDir;
      } else {
        // Stopped or reached max extent
        if (cushionHit != null) {
          strikerPath.add(cushionHit.hitPoint);
        } else {
          strikerPath.add(currentOrigin + currentDir * 200);
        }
        break;
      }
    }

    // Now calculate coin trajectory if a coin was hit
    List<Offset> coinPath = [];
    if (hitCoinIndex != null && coinDeflectionDir != null && coinImpactPoint != null) {
      coinPath.add(coinImpactPoint);
      final coinMinX = cushionInset + coinRadius;
      final coinMaxX = boardSize - cushionInset - coinRadius;
      final coinMinY = cushionInset + coinRadius;
      final coinMaxY = boardSize - cushionInset - coinRadius;

      // Project coin to first cushion or pocket
      final coinCushion = _rayCushionIntersection(
        origin: coinImpactPoint,
        dir: coinDeflectionDir,
        minX: coinMinX,
        maxX: coinMaxX,
        minY: coinMinY,
        maxY: coinMaxY,
      );

      if (coinCushion != null) {
        coinPath.add(coinCushion.hitPoint);
        // Add 1 bank bounce for coin
        final bankBouncePoint = coinCushion.hitPoint + coinCushion.newDir * 80;
        coinPath.add(bankBouncePoint);
      } else {
        coinPath.add(coinImpactPoint + coinDeflectionDir * 180);
      }
    }

    // Check which pocket the coin path is heading to
    final pockets = getPocketPositions(boardSize, cushionInset);
    int? targetedPocketIndex;
    if (coinPath.length >= 2) {
      final p1 = coinPath[0];
      final p2 = coinPath[1];
      for (int i = 0; i < pockets.length; i++) {
        final dist = _distanceToSegment(pockets[i], p1, p2);
        if (dist < coinRadius * 2.2) {
          targetedPocketIndex = i;
          break;
        }
      }
    }

    return AimSimulationResult(
      strikerPath: strikerPath,
      coinPath: coinPath,
      hitCoinIndex: hitCoinIndex,
      strikerDeflectionDir: strikerDeflectionDir,
      coinDeflectionDir: coinDeflectionDir,
      targetedPocketIndex: targetedPocketIndex,
    );
  }

  static List<Offset> getPocketPositions(double boardSize, double cushionInset) {
    final margin = cushionInset + 16.0;
    return [
      Offset(margin, margin), // Top Left
      Offset(boardSize - margin, margin), // Top Right
      Offset(margin, boardSize - margin), // Bottom Left
      Offset(boardSize - margin, boardSize - margin), // Bottom Right
    ];
  }

  static Offset _normalize(Offset v) {
    final len = v.distance;
    if (len == 0) return const Offset(1, 0);
    return Offset(v.dx / len, v.dy / len);
  }

  static _RayHit? _rayCircleIntersection({
    required Offset rayOrigin,
    required Offset rayDir,
    required Offset circleCenter,
    required double combinedRadius,
  }) {
    // Vector from origin to circle center
    final m = rayOrigin - circleCenter;
    final b = m.dx * rayDir.dx + m.dy * rayDir.dy;
    final c = (m.dx * m.dx + m.dy * m.dy) - (combinedRadius * combinedRadius);

    if (c > 0 && b > 0) return null; // Ray origin outside circle and pointing away

    final discr = b * b - c;
    if (discr < 0) return null; // No real roots

    double t = -b - math.sqrt(discr);
    if (t < 0) t = 0;

    return _RayHit(t: t, point: rayOrigin + rayDir * t);
  }

  static _CushionHit? _rayCushionIntersection({
    required Offset origin,
    required Offset dir,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
  }) {
    double minT = double.infinity;
    Offset? hitNormal;

    // Check vertical cushions (Left & Right)
    if (dir.dx < 0) {
      final t = (minX - origin.dx) / dir.dx;
      if (t > 0.001 && t < minT) {
        final y = origin.dy + t * dir.dy;
        if (y >= minY && y <= maxY) {
          minT = t;
          hitNormal = const Offset(1, 0);
        }
      }
    } else if (dir.dx > 0) {
      final t = (maxX - origin.dx) / dir.dx;
      if (t > 0.001 && t < minT) {
        final y = origin.dy + t * dir.dy;
        if (y >= minY && y <= maxY) {
          minT = t;
          hitNormal = const Offset(-1, 0);
        }
      }
    }

    // Check horizontal cushions (Top & Bottom)
    if (dir.dy < 0) {
      final t = (minY - origin.dy) / dir.dy;
      if (t > 0.001 && t < minT) {
        final x = origin.dx + t * dir.dx;
        if (x >= minX && x <= maxX) {
          minT = t;
          hitNormal = const Offset(0, 1);
        }
      }
    } else if (dir.dy > 0) {
      final t = (maxY - origin.dy) / dir.dy;
      if (t > 0.001 && t < minT) {
        final x = origin.dx + t * dir.dx;
        if (x >= minX && x <= maxX) {
          minT = t;
          hitNormal = const Offset(0, -1);
        }
      }
    }

    if (hitNormal != null && minT < double.infinity) {
      final hitPoint = origin + dir * minT;
      // Reflection: r = d - 2*(d.n)*n
      final dot = dir.dx * hitNormal.dx + dir.dy * hitNormal.dy;
      final reflected = Offset(
        dir.dx - 2 * dot * hitNormal.dx,
        dir.dy - 2 * dot * hitNormal.dy,
      );
      return _CushionHit(
        dist: minT,
        hitPoint: hitPoint,
        newDir: _normalize(reflected),
      );
    }

    return null;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = math.max(0, math.min(1, t));
    final proj = Offset(a.dx + t * (b.dx - a.dx), a.dy + t * (b.dy - a.dy));
    return (p - proj).distance;
  }
}

class _RayHit {
  final double t;
  final Offset point;
  _RayHit({required this.t, required this.point});
}

class _CushionHit {
  final double dist;
  final Offset hitPoint;
  final Offset newDir;
  _CushionHit({required this.dist, required this.hitPoint, required this.newDir});
}

class AimSimulationResult {
  final List<Offset> strikerPath;
  final List<Offset> coinPath;
  final int? hitCoinIndex;
  final Offset? strikerDeflectionDir;
  final Offset? coinDeflectionDir;
  final int? targetedPocketIndex;

  AimSimulationResult({
    required this.strikerPath,
    required this.coinPath,
    this.hitCoinIndex,
    this.strikerDeflectionDir,
    this.coinDeflectionDir,
    this.targetedPocketIndex,
  });
}
