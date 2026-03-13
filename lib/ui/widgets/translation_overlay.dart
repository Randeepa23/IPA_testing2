// lib/widgets/translation_overlay.dart

import 'package:flutter/material.dart';
import '../../Services/ocr_service.dart';

/// Paints translated text blocks over the original image positions
class TranslationOverlayPainter extends CustomPainter {
  final List<TranslatedBlock> blocks;
  final Size imageSize;
  final Size widgetSize;

  TranslationOverlayPainter({
    required this.blocks,
    required this.imageSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    for (final block in blocks) {
      if (block.translatedText.isEmpty) continue;

      final rect = Rect.fromLTRB(
        block.originalBlock.boundingBox.left * scaleX,
        block.originalBlock.boundingBox.top * scaleY,
        block.originalBlock.boundingBox.right * scaleX,
        block.originalBlock.boundingBox.bottom * scaleY,
      );

      // Background box (white, like Google Lens)
      final bgPaint = Paint()
        ..color = Colors.white.withOpacity(0.92)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        bgPaint,
      );

      // Border
      final borderPaint = Paint()
        ..color = const Color(0xFF4285F4).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        borderPaint,
      );

      // Translated text
      final fontSize = (rect.height * 0.45).clamp(8.0, 18.0);
      final textSpan = TextSpan(
        text: block.translatedText,
        style: TextStyle(
          color: const Color(0xFF1A1A2E),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: null,
      );
      tp.layout(maxWidth: rect.width - 8);
      tp.paint(canvas, Offset(rect.left + 4, rect.top + (rect.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(TranslationOverlayPainter oldDelegate) =>
      oldDelegate.blocks != blocks;
}

class TranslatedBlock {
  final TextBlock originalBlock;
  final String translatedText;

  TranslatedBlock({
    required this.originalBlock,
    required this.translatedText,
  });
}

/// The full overlay widget with scanning animation
class ScannerOverlay extends StatefulWidget {
  final bool isScanning;
  const ScannerOverlay({super.key, required this.isScanning});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isScanning) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return CustomPaint(
          painter: _ScanLinePainter(_anim.value),
          child: Container(),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // Scan line glow
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          const Color(0xFF4285F4).withOpacity(0.8),
          const Color(0xFF4FC3F7),
          const Color(0xFF4285F4).withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4));

    canvas.drawRect(
      Rect.fromLTWH(0, y - 2, size.width, 4),
      paint,
    );

    // Corner markers
    const cornerSize = 20.0;
    const cornerWidth = 3.0;
    const padding = 20.0;
    final cornerPaint = Paint()
      ..color = const Color(0xFF4FC3F7)
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(padding, padding), Offset(padding + cornerSize, padding), cornerPaint);
    canvas.drawLine(Offset(padding, padding), Offset(padding, padding + cornerSize), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding - cornerSize, padding), cornerPaint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerSize), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerSize, size.height - padding), cornerPaint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding, size.height - padding - cornerSize), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding - cornerSize, size.height - padding), cornerPaint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerSize), cornerPaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}