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

// System Floating Overlay entry point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CarromInGameOverlay(),
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
  final double boardSize = 400.0;
  final double strikerRadius = 18.0;
  final double coinRadius = 14.0;
  final double cushionInset = 28.0;

  late Offset strikerPos;
  double aimAngle = -math.pi / 2;
  bool showCushionBounce = true;
  bool showCoinDeflection = true;
  bool isOverlayActive = false;

  late List<Offset> coins;
  late List<CoinType> coinTypes;

  int? draggedCoinIndex;
  bool isDraggingStriker = false;
  bool isAiming = false;

  @override
  void initState() {
    super.initState();
    _resetPositions();
    _checkOverlayState();
  }

  Future<void> _checkOverlayState() async {
    try {
      final active = await FlutterOverlayWindow.isActive();
      if (mounted) setState(() => isOverlayActive = active);
    } catch (_) {}
  }

  void _resetPositions() {
    final center = boardSize / 2;
    strikerPos = Offset(center, boardSize - cushionInset - 40.0);

    coins = [
      Offset(center, center), // Queen
      Offset(center - 24, center),
      Offset(center + 24, center),
      Offset(center, center - 24),
      Offset(center, center + 24),
      Offset(center - 18, center - 20),
      Offset(center + 18, center + 20),
      Offset(center - 18, center + 20),
      Offset(center + 18, center - 20),
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
              const SnackBar(
                content: Text('⚠️ Please enable "Display over other apps" permission in Settings'),
                backgroundColor: Colors.redAccent,
              ),
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
        // Show Full Screen overlay so guidelines float right on top of Carrom Disc Pool
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false,
          overlayTitle: "Carrom Aim Guideline",
          overlayContent: 'Aim bot active on Carrom Pool',
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
        );
        setState(() => isOverlayActive = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎯 Floating Overlay Started! Switch to Carrom Disc Pool.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching overlay: $e')),
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
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Collision & Trajectory Predictor',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Enter PiP',
            icon: const Icon(Icons.picture_in_picture_alt, color: Color(0xFF00E5FF)),
            onPressed: () {
              PIPView.of(context)?.presentBelow(
                const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Text('Underlying Game Screen', style: TextStyle(color: Colors.white30)),
                  ),
                ),
              );
            },
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
                // Quick Launch Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOverlayActive
                          ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                          : [const Color(0xFF0F2027), const Color(0xFF203A43)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOverlayActive ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverlayActive ? Icons.check_circle : Icons.sports_esports,
                        color: isOverlayActive ? Colors.greenAccent : const Color(0xFF00E5FF),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOverlayActive ? 'Floating Overlay Active' : 'Start Over Carrom Game',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              isOverlayActive
                                  ? 'Switch to Carrom Disc Pool to use aim guidelines!'
                                  : 'Floats translucent extended guidelines directly over the game board.',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOverlayActive ? Colors.redAccent : const Color(0xFF00E5FF),
                          foregroundColor: isOverlayActive ? Colors.white : Colors.black,
                        ),
                        onPressed: _toggleSystemOverlay,
                        child: Text(isOverlayActive ? 'Stop' : 'Start'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
      color: Colors.black.withValues(alpha: 0.65),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00E5FF)),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF9100)),
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00E676)),
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
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
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
              if ((pos - strikerPos).distance <= strikerRadius * 1.8) {
                isDraggingStriker = true;
                return;
              }
              for (int i = 0; i < coins.length; i++) {
                if ((pos - coins[i]).distance <= coinRadius * 1.8) {
                  draggedCoinIndex = i;
                  return;
                }
              }
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
                setState(() => strikerPos = clamped);
              } else if (draggedCoinIndex != null) {
                setState(() => coins[draggedCoinIndex!] = clamped);
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
              const Text('Striker Baseline Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${(strikerPos.dx).toInt()} px', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
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
            onChanged: (val) => setState(() => strikerPos = Offset(val, strikerPos.dy)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fine Angle Adjustment (Degree)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${(aimAngle * 180 / math.pi).toStringAsFixed(1)}°', style: const TextStyle(color: Color(0xFFFF9100), fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            min: -math.pi,
            max: 0,
            value: aimAngle.clamp(-math.pi, 0),
            activeColor: const Color(0xFFFF9100),
            onChanged: (val) => setState(() => aimAngle = val),
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cushion Bank Bounce Lines'),
              Switch(
                value: showCushionBounce,
                activeThumbColor: const Color(0xFF00E5FF),
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
                activeThumbColor: const Color(0xFF00E676),
                onChanged: (v) => setState(() => showCoinDeflection = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// In-Game Floating HUD Overlay
class CarromInGameOverlay extends StatefulWidget {
  const CarromInGameOverlay({super.key});

  @override
  State<CarromInGameOverlay> createState() => _CarromInGameOverlayState();
}

class _CarromInGameOverlayState extends State<CarromInGameOverlay> {
  // Screen and board dimensions
  double boardPixelSize = 360.0;
  Offset strikerPos = const Offset(180, 280);
  double aimAngle = -math.pi / 2;
  bool isTransparentMode = false;

  // Real coin positions on board for simulation
  List<Offset> coins = [
    const Offset(180, 180), // Queen Center
    const Offset(160, 180),
    const Offset(200, 180),
    const Offset(180, 160),
    const Offset(180, 200),
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
      child: Stack(
        children: [
          // 1. Aim line overlay canvas (matches Carrom board area)
          Center(
            child: SizedBox(
              width: boardPixelSize,
              height: boardPixelSize,
              child: CustomPaint(
                painter: AimLinesPainter(
                  strikerPos: strikerPos,
                  aimDir: Offset(math.cos(aimAngle), math.sin(aimAngle)),
                  coins: coins,
                  coinTypes: coinTypes,
                  boardSize: boardPixelSize,
                  showCushionReflection: true,
                  showCoinDeflection: true,
                  drawBoardBackground: !isTransparentMode,
                ),
              ),
            ),
          ),

          // 2. Floating Controller Pill at top
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xEE0F172A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed, color: Color(0xFF00E5FF), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Aim: ${(aimAngle * 180 / math.pi).toStringAsFixed(0)}°',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        isTransparentMode ? Icons.layers : Icons.layers_clear,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                      tooltip: 'Toggle Transparent HUD',
                      onPressed: () => setState(() => isTransparentMode = !isTransparentMode),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                      tooltip: 'Close Overlay',
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Draggable Aim Joystick / Handle
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xCC1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Drag slider to align with in-game arrow',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Slider(
                      value: aimAngle.clamp(-math.pi, 0),
                      min: -math.pi,
                      max: 0,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (val) => setState(() => aimAngle = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
