import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

enum _InteractionTarget { none, rotate, zoom }

class CameraControl extends StatefulWidget {
  final double horizontalAngle;
  final double verticalAngle;
  final double zoom;
  final ValueChanged<double> onHorizontalChanged;
  final ValueChanged<double> onVerticalChanged;
  final ValueChanged<double> onZoomChanged;

  const CameraControl({
    super.key,
    required this.horizontalAngle,
    required this.verticalAngle,
    required this.zoom,
    required this.onHorizontalChanged,
    required this.onVerticalChanged,
    required this.onZoomChanged,
  });

  @override
  State<CameraControl> createState() => _CameraControlState();
}

class _CameraControlState extends State<CameraControl> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _hAnim, _vAnim, _zAnim;
  
  _InteractionTarget _target = _InteractionTarget.none;
  double _baseZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _setupAnimations(widget.horizontalAngle, widget.verticalAngle, widget.zoom);
    _baseZoom = widget.zoom;
  }

  void _setupAnimations(double h, double v, double z) {
    _hAnim = Tween<double>(begin: h, end: h).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _vAnim = Tween<double>(begin: v, end: v).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _zAnim = Tween<double>(begin: z, end: z).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(CameraControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_target == _InteractionTarget.none && 
        (widget.horizontalAngle != oldWidget.horizontalAngle || 
         widget.verticalAngle != oldWidget.verticalAngle || 
         widget.zoom != oldWidget.zoom)) {
      _hAnim = Tween<double>(begin: _hAnim.value, end: widget.horizontalAngle).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
      _vAnim = Tween<double>(begin: _vAnim.value, end: widget.verticalAngle).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
      _zAnim = Tween<double>(begin: _zAnim.value, end: widget.zoom).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final h = _animController.isAnimating ? _hAnim.value : widget.horizontalAngle;
        final v = _animController.isAnimating ? _vAnim.value : widget.verticalAngle;
        final z = _animController.isAnimating ? _zAnim.value : widget.zoom;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF010208),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildModernHeader(),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 3D Viewport
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Stack(
                          children: [
                            CustomPaint(
                              painter: _HolographicRigPainter(
                                horizontalAngle: h,
                                verticalAngle: v,
                                zoom: z,
                              ),
                              size: Size.infinite,
                            ),
                            
                            GestureDetector(
                              onScaleStart: (details) {
                                _animController.stop();
                                _baseZoom = widget.zoom;
                                _target = _InteractionTarget.rotate;
                              },
                              onScaleUpdate: (details) {
                                if (details.pointerCount == 1) {
                                  // Rotation
                                  final dx = details.focalPointDelta.dx;
                                  final dy = details.focalPointDelta.dy;
                                  widget.onHorizontalChanged((widget.horizontalAngle - dx * 0.5) % 360);
                                  widget.onVerticalChanged((widget.verticalAngle + dy * 0.5).clamp(-90, 90));
                                } else if (details.pointerCount == 2) {
                                  // Pinch Zoom
                                  final newZoom = (_baseZoom / details.scale).clamp(1.0, 10.0);
                                  widget.onZoomChanged(newZoom);
                                }
                              },
                              onScaleEnd: (_) => _target = _InteractionTarget.none,
                              onDoubleTap: () {
                                widget.onHorizontalChanged(0);
                                widget.onVerticalChanged(0);
                                widget.onZoomChanged(5.0);
                              },
                              child: Container(color: Colors.transparent),
                            ),
                            
                            _buildTelemetryOverlay(h, v, z),
                            
                            Positioned(
                              top: 15, left: 15,
                              child: _buildSelectionControls(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 2. Vertical Zoom Slider (Far/Near)
                  _buildZoomSlider(z),
                ],
              ),

              const SizedBox(height: 20),
              _buildStatusRow(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomSlider(double z) => Column(
    children: [
      const Text("NEAR", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        height: 220,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: const Color(0xFFC91B65),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFFC91B65).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: z,
                    min: 1.0,
                    max: 10.0,
                    onChanged: (v) => widget.onZoomChanged(v),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Text("FAR", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildModernHeader() => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFC91B65).withOpacity(0.1)),
        child: const Icon(Icons.videocam_outlined, size: 20, color: Color(0xFFC91B65)),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CAMERA STUDIO", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          Text("DRAG TO ROTATE • PINCH TO ZOOM", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w500)),
        ],
      ),
      const Spacer(),
      _buildIconButton(Icons.refresh, () {
        widget.onHorizontalChanged(0); widget.onVerticalChanged(0); widget.onZoomChanged(5.0);
      }),
    ],
  );

  Widget _buildTelemetryOverlay(double h, double v, double z) => Positioned(
    bottom: 15, left: 15,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _telemetryItem("AZIMUTH", "${h.toStringAsFixed(0)}°"),
          const SizedBox(height: 4),
          _telemetryItem("ZENITH", "${v.toStringAsFixed(0)}°"),
          const SizedBox(height: 4),
          _telemetryItem("DISTANCE", z.toStringAsFixed(1)),
        ],
      ),
    ),
  );

  Widget _telemetryItem(String label, String val) => Row(
    children: [
      Text(label, style: const TextStyle(color: Colors.white24, fontSize: 7, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Text(val, style: const TextStyle(color: Colors.white70, fontSize: 9, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildSelectionControls() => Row(
    children: [
      _miniPreset("正面", 0, 0),
      const SizedBox(width: 8),
      _miniPreset("侧面", 90, 0),
      const SizedBox(width: 8),
      _miniPreset("背面", 180, 0),
      const SizedBox(width: 8),
      _miniPreset("顶视", 0, 90),
    ],
  );

  Widget _miniPreset(String label, double h, double v) {
    final active = (widget.horizontalAngle - h).abs() < 5 && (widget.verticalAngle - v).abs() < 5;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onHorizontalChanged(h);
        widget.onVerticalChanged(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFC91B65) : Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.white30 : Colors.white10),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusRow() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app, size: 14, color: Color(0xFF00E5FF)),
        SizedBox(width: 8),
        Text("360° SPHERICAL CONTROL ACTIVE", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildIconButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
      child: Icon(icon, size: 18, color: Colors.white70),
    ),
  );
}

class _HolographicRigPainter extends CustomPainter {
  final double horizontalAngle, verticalAngle, zoom;

  _HolographicRigPainter({required this.horizontalAngle, required this.verticalAngle, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;
    final rigRadius = baseRadius * (zoom / 5.0).clamp(0.4, 2.5);

    // 1. Draw Environment
    _drawAtmosphere(canvas, center, size.width * 0.5);

    // 2. Calculations
    final camPos = _getSpherePos(rigRadius, horizontalAngle - 90, verticalAngle);
    final pCam = _project(camPos, center, size.width);

    // 3. Draw Grid & Compass
    _drawGridSphere(canvas, center, rigRadius);
    _drawCompass(canvas, center, rigRadius + 15, horizontalAngle);

    // 4. Draw Central Subject
    _drawSubject(canvas, center, baseRadius * 0.25, horizontalAngle, verticalAngle);

    // 5. Draw Camera Node
    _drawCameraNode(canvas, pCam, center);
  }

  void _drawAtmosphere(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..shader = RadialGradient(colors: [const Color(0xFF10221C).withOpacity(0.2), Colors.transparent]).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawGridSphere(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = 0.5;
    
    // Latitude rings
    for (int i = -2; i <= 2; i++) {
      double lat = i * 30.0;
      double r = radius * math.cos(lat * math.pi / 180);
      double y = -radius * math.sin(lat * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: center + Offset(0, y), width: r * 2, height: r * 0.2), paint);
    }

    // Longitude lines
    for (int i = 0; i < 4; i++) {
      double lon = i * 45.0;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(lon * math.pi / 180);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 0.2, height: radius * 2), paint);
      canvas.restore();
    }
  }

  void _drawSubject(Canvas canvas, Offset center, double s, double hDeg, double vDeg) {
    final h = hDeg * math.pi / 180;
    final v = vDeg * math.pi / 180;
    
    final points = [
      v64.Vector3(0, -s*1.2, 0), v64.Vector3(0, s*1.2, 0), // Y axis
      v64.Vector3(s, 0, 0), v64.Vector3(-s, 0, 0),       // X axis
      v64.Vector3(0, 0, s*1.5),                          // Front (Nose)
    ];

    final m = v64.Matrix4.identity()..rotateY(-h)..rotateX(v);
    final projected = points.map((p) => _project(m.transform3(p), center, s * 15)).toList();

    final paint = Paint()..color = const Color(0xFFC91B65).withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke;
    
    // Base shape
    canvas.drawLine(projected[0], projected[2], paint);
    canvas.drawLine(projected[0], projected[3], paint);
    canvas.drawLine(projected[1], projected[2], paint);
    canvas.drawLine(projected[1], projected[3], paint);
    
    // Directional indicator
    final nosePaint = Paint()..color = Colors.white..strokeWidth = 2;
    canvas.drawLine(projected[0], projected[4], nosePaint);
    canvas.drawLine(projected[1], projected[4], nosePaint);
    canvas.drawCircle(projected[4], 3, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  void _drawCameraNode(Canvas canvas, Offset p, Offset center) {
    // Connection line
    canvas.drawLine(center, p, Paint()..color = Colors.white10..strokeWidth = 1);
    
    // Camera Icon/Node
    final r = 12.0;
    canvas.drawCircle(p, r * 2, Paint()..color = const Color(0xFFC91B65).withOpacity(0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(p, r, Paint()..color = const Color(0xFFC91B65)..style = PaintingStyle.fill);
    canvas.drawCircle(p, r, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    
    const icon = Icons.camera_alt;
    final tp = TextPainter(text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: icon.fontFamily)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawCompass(Canvas canvas, Offset center, double radius, double hDeg) {
    final labels = ["N", "E", "S", "W"];
    for (int i = 0; i < 4; i++) {
      double angle = (i * 90 - 90 - hDeg) * math.pi / 180;
      Offset p = center + Offset(radius * math.cos(angle), radius * 0.2 * math.sin(angle));
      final tp = TextPainter(text: TextSpan(text: labels[i], style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  v64.Vector3 _getSpherePos(double r, double hDeg, double vDeg) {
    final h = hDeg * math.pi / 180; final v = vDeg * math.pi / 180;
    return v64.Vector3(r * math.cos(v) * math.cos(h), -r * math.sin(v), r * math.cos(v) * math.sin(h));
  }

  Offset _project(v64.Vector3 p, Offset center, double range) {
    final factor = 1.0 / (1.0 + (p.z / range) * 0.5);
    return Offset(center.dx + p.x * factor, center.dy + p.y * factor);
  }

  @override
  bool shouldRepaint(covariant _HolographicRigPainter old) => true;
}
