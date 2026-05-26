import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/constants.dart';

/// Full-screen camera barcode scanner.
/// Returns the scanned barcode string via Navigator.pop(context, value).
/// Returns null if the user cancels.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _torchOn = false;
  bool _detected = false;
  final TextEditingController _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value != null && value.isNotEmpty) {
      _detected = true;
      _ctrl.stop();
      Navigator.pop(context, value);
    }
  }

  void _submitManual() {
    final code = _manualCtrl.text.trim();
    if (code.isEmpty) return;
    _detected = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            tooltip: 'الفلاش',
            onPressed: () {
              _ctrl.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            tooltip: 'تبديل الكاميرا',
            onPressed: _ctrl.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera view ──────────────────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // ── Scanning frame overlay ───────────────────────────────────
          _ScanOverlay(),

          // ── Bottom panel ─────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'وجّه الكاميرا نحو الباركود',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 16),

                  // ── Manual entry fallback ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCtrl,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'أو أدخل الكود يدوياً',
                            hintStyle:
                                const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white12,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(AppColors.primaryInt),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submitManual,
                        child: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scan Frame Overlay ───────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const frameSize = 240.0;
    final top = (size.height - frameSize) / 2 - 40;
    final left = (size.width - frameSize) / 2;

    return Stack(
      children: [
        // Dark corners mask
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(color: Colors.transparent),
              Positioned(
                top: top,
                left: left,
                child: Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Corner brackets
        Positioned(
          top: top,
          left: left,
          child: _CornerBrackets(size: frameSize),
        ),
        // Scan line animation
        Positioned(
          top: top,
          left: left,
          child: _ScanLine(frameSize: frameSize),
        ),
      ],
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  final double size;

  const _CornerBrackets({required this.size});

  @override
  Widget build(BuildContext context) {
    const c = Color(AppColors.accentInt);
    const w = 3.0;
    const len = 24.0;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BracketPainter(color: c, strokeWidth: w, cornerLen: len),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLen;

  _BracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const r = 8.0;
    final w = size.width;
    final h = size.height;
    final l = cornerLen;

    // Top-left
    canvas.drawLine(Offset(r, 0), Offset(l, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, l), paint);
    canvas.drawArc(
        const Rect.fromLTWH(0, 0, r * 2, r * 2), 3.14159, -1.5708, false,
        paint);

    // Top-right
    canvas.drawLine(Offset(w - l, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, l), paint);
    canvas.drawArc(
        Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2), 4.71239, -1.5708, false,
        paint);

    // Bottom-left
    canvas.drawLine(Offset(r, h), Offset(l, h), paint);
    canvas.drawLine(Offset(0, h - r), Offset(0, h - l), paint);
    canvas.drawArc(
        Rect.fromLTWH(0, h - r * 2, r * 2, r * 2), 1.5708, -1.5708, false,
        paint);

    // Bottom-right
    canvas.drawLine(Offset(w - l, h), Offset(w - r, h), paint);
    canvas.drawLine(Offset(w, h - l), Offset(w, h - r), paint);
    canvas.drawArc(
        Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2), 0, -1.5708,
        false, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

class _ScanLine extends StatefulWidget {
  final double frameSize;

  const _ScanLine({required this.frameSize});

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _pos;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pos = Tween<double>(begin: 8, end: widget.frameSize - 8).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pos,
      builder: (_, __) => Positioned(
        top: _pos.value,
        left: 8,
        child: Container(
          width: widget.frameSize - 16,
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(AppColors.accentInt).withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
