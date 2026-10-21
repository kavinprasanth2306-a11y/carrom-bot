import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:pip_view/pip_view.dart';
import 'physics/carrom_physics.dart';
import 'physics/aim_lines_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CarromAimBotApp());
}

// Overlay entrypoint invoked when Android floating window launches
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CarromFloatingOverlay(),
    ),
  );
}

class CarromAimBotApp extends StatelessWidget {
  const CarromAimBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carrom Disc Pool Aim Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF9100),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const PIPView(
        builder: _buildPipView,
      ),
    );
  }

  static Widget _buildPipView(BuildContext context, bool isFloating) {
    return CarromBotHome(isFloating: isFloating);
  }
}

class CarromBotHome extends StatefulWidget {
  final bool isFloating;
  const CarromBotHome({super.key, this.isFloating = false});

  @override
  State<CarromBotHome> createState() => _CarromBotHomeState();
}

class _CarromBotHomeState extends State<CarromBotHome> {
  // Board setup
  final double boardSize = 400.0;
  final double strikerRadius = 18.0;
  final double coinRadius = 14.0;
  final double cushionInset = 28.0;

  // Aim state
  late Offset strikerPos;
  double aimAngle = -math.pi / 2; // Pointing upwards initially
  double power = 0.75;
  bool showCushionBounce = true;
  bool showCoinDeflection = true;
  bool isOverlayActive = false;

  // Coins positions & types
  late List<Offset> coins;
  late List<CoinType> coinTypes;

  // Dragging state
  int? draggedCoinIndex;
  bool isDraggingStriker = false;
  bool isAiming = false;

  @override
  void initState() {
    super.initState();
    _resetPositions();
  }

  void _resetPositions() {
    final center = boardSize / 2;
    strikerPos = Offset(center, boardSize - cushionInset - 40.0);

    // Initial default carrom coin cluster around center
    coins = [
      Offset(center, center), // Queen
      Offset(center - 24, center), // White
      Offset(center + 24, center), // White
      Offset(center, center - 24), // Black
      Offset(center, center + 24), // Black
      Offset(center - 18, center - 20), // Black
      Offset(center + 18, center + 20), // White
      Offset(center - 18, center + 20), // White
      Offset(center + 18, center - 20), // Black
    ];

    coinTypes = [
      CoinType.queen,
      CoinType.white,
      CoinType.white,
      CoinType.black,
      CoinType.black,
      CoinType.black,
      CoinType.white,
      CoinType.white,
      CoinType.black,
    ];
  }

  Offset get aimDir => Offset(math.cos(aimAngle), math.sin(aimAngle));

  Future<void> _toggleSystemOverlay() async {
    try {
      final isGranted = await FlutterOverlayWindow.isPermissionGranted();
      if (!isGranted) {
        final res = await FlutterOverlayWindow.requestPermission();
        if (res != true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Overlay permission denied')),
            );
          }
          return;
        }
      }

      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
        setState(() => isOverlayActive = false);
      } else {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "Carrom Aim Guideline",
          overlayContent: 'Aim bot active',
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          width: 900,
          height: 900,
        );
        setState(() => isOverlayActive = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Overlay not supported on this platform: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFloating) {
      return _buildFloatingPipContent();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.gps_fixed, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carrom Aim Assistant',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Real-time Collision & Trajectory Guideline',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Enter PiP (Picture in Picture)',
            icon: const Icon(Icons.picture_in_picture_alt, color: Color(0xFF00E5FF)),
            onPressed: () {
              PIPView.of(context)?.presentBelow(
                Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Text(
                      'Background App',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Launch System Floating Overlay',
            icon: Icon(
              isOverlayActive ? Icons.layers_clear : Icons.layers,
              color: isOverlayActive ? Colors.greenAccent : Colors.white,
            ),
            onPressed: _toggleSystemOverlay,
          ),
          IconButton(
            tooltip: 'Reset board',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_resetPositions),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                _buildControlHeader(),
                const SizedBox(height: 12),
                _buildInteractiveBoard(),
                const SizedBox(height: 16),
                _buildAimControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingPipContent() {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: AimLinesPainter(
              strikerPos: strikerPos,
              aimDir: aimDir,
              coins: coins,
              coinTypes: coinTypes,
              boardSize: boardSize,
              strikerRadius: strikerRadius,
              coinRadius: coinRadius,
              cushionInset: cushionInset,
              showCushionReflection: showCushionBounce,
              showCoinDeflection: showCoinDeflection,
              drawBoardBackground: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Striker Line', style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF9100),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Coin Path', style: TextStyle(fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Pocket Target', style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveBoard() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: boardSize, maxHeight: boardSize),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onPanStart: (details) {
              final pos = details.localPosition;
              // Check if touching striker
              if ((pos - strikerPos).distance <= strikerRadius * 1.8) {
                isDraggingStriker = true;
                return;
              }

              // Check if touching any coin
              for (int i = 0; i < coins.length; i++) {
                if ((pos - coins[i]).distance <= coinRadius * 1.8) {
                  draggedCoinIndex = i;
                  return;
                }
              }

              // Else we are aiming striker towards touch point
              isAiming = true;
              setState(() {
                final diff = pos - strikerPos;
                aimAngle = math.atan2(diff.dy, diff.dx);
              });
            },
            onPanUpdate: (details) {
              final pos = details.localPosition;
              final minBound = cushionInset + coinRadius;
              final maxBound = boardSize - cushionInset - coinRadius;
              final clamped = Offset(
                pos.dx.clamp(minBound, maxBound),
                pos.dy.clamp(minBound, maxBound),
              );

              if (isDraggingStriker) {
                setState(() {
                  // Keep striker on baseline or allow free move in practice
                  strikerPos = clamped;
                });
              } else if (draggedCoinIndex != null) {
                setState(() {
                  coins[draggedCoinIndex!] = clamped;
                });
              } else if (isAiming) {
                setState(() {
                  final diff = pos - strikerPos;
                  aimAngle = math.atan2(diff.dy, diff.dx);
                });
              }
            },
            onPanEnd: (_) {
              isDraggingStriker = false;
              draggedCoinIndex = null;
              isAiming = false;
            },
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: AimLinesPainter(
                strikerPos: strikerPos,
                aimDir: aimDir,
                coins: coins,
                coinTypes: coinTypes,
                boardSize: boardSize,
                strikerRadius: strikerRadius,
                coinRadius: coinRadius,
                cushionInset: cushionInset,
                showCushionReflection: showCushionBounce,
                showCoinDeflection: showCoinDeflection,
                drawBoardBackground: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAimControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Striker Baseline Position',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${(strikerPos.dx).toInt()} px',
                style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            min: cushionInset + strikerRadius + 20,
            max: boardSize - cushionInset - strikerRadius - 20,
            value: strikerPos.dx.clamp(
              cushionInset + strikerRadius + 20,
              boardSize - cushionInset - strikerRadius - 20,
            ),
            activeColor: const Color(0xFF00E5FF),
            onChanged: (val) {
              setState(() {
                strikerPos = Offset(val, strikerPos.dy);
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fine Angle Adjustment (Degree)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${(aimAngle * 180 / math.pi).toStringAsFixed(1)}°',
                style: const TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            min: -math.pi,
            max: 0,
            value: aimAngle.clamp(-math.pi, 0),
            activeColor: const Color(0xFFFF9100),
            onChanged: (val) {
              setState(() {
                aimAngle = val;
              });
            },
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cushion Bank Bounce Lines'),
              Switch(
                value: showCushionBounce,
                activeColor: const Color(0xFF00E5FF),
                onChanged: (v) => setState(() => showCushionBounce = v),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Coin Path & Pocket Predictor'),
              Switch(
                value: showCoinDeflection,
                activeColor: const Color(0xFF00E676),
                onChanged: (v) => setState(() => showCoinDeflection = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '💡 Touch board to aim • Drag coins to match your game state • Tap PiP button to float over game',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Overlay widget when launched in system overlay mode
class CarromFloatingOverlay extends StatefulWidget {
  const CarromFloatingOverlay({super.key});

  @override
  State<CarromFloatingOverlay> createState() => _CarromFloatingOverlayState();
}

class _CarromFloatingOverlayState extends State<CarromFloatingOverlay> {
  final double boardSize = 340.0;
  Offset strikerPos = const Offset(170, 290);
  double aimAngle = -math.pi / 2;
  List<Offset> coins = [
    const Offset(170, 170),
    const Offset(140, 170),
    const Offset(200, 170),
    const Offset(170, 140),
    const Offset(170, 200),
  ];
  List<CoinType> coinTypes = [
    CoinType.queen,
    CoinType.white,
    CoinType.white,
    CoinType.black,
    CoinType.black,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: boardSize,
          height: boardSize + 50,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x6600E5FF), width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xAA0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🎯 Aim Bot PiP Guideline',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 16),
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final pos = details.localPosition;
                    final diff = pos - strikerPos;
                    setState(() {
                      aimAngle = math.atan2(diff.dy, diff.dx);
                    });
                  },
                  child: CustomPaint(
                    size: Size(boardSize, boardSize),
                    painter: AimLinesPainter(
                      strikerPos: strikerPos,
                      aimDir: Offset(math.cos(aimAngle), math.sin(aimAngle)),
                      coins: coins,
                      coinTypes: coinTypes,
                      boardSize: boardSize,
                      showCushionReflection: true,
                      showCoinDeflection: true,
                      drawBoardBackground: false, // Transparent so user sees game underneath!
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
