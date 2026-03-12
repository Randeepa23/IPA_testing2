// lib/screens/camera_screen.dart

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../Models/language_model.dart';
import '../Services/ocr_service.dart';
import '../Services/translation_service.dart';
import '../ui/widgets/language_selector.dart';
import '../ui/widgets/translation_overlay.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isLiveMode = false; // Live real-time OCR mode
  bool _flashOn = false;

  AppLanguage _sourceLang = kLanguages[1]; // Sinhala default
  AppLanguage _targetLang = kLanguages[0]; // English default

  // Live mode state
  String _liveText = '';
  bool _isLiveProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;

    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    OcrService.dispose();
    TranslationService.dispose();
    super.dispose();
  }

  // ─── CAPTURE & TRANSLATE ─────────────────────────────────────
// In _captureAndTranslate(), add stopImageStream FIRST:
Future<void> _captureAndTranslate() async {
  if (!_isInitialized || _isProcessing) return;
  setState(() => _isProcessing = true);

  try {
    // ADD THIS - stop stream before taking picture
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }

    HapticFeedback.mediumImpact();
    final image = await _controller!.takePicture();
    final file = File(image.path);
    await _processAndNavigate(file);
  } catch (e) {
    _showError('Capture failed: $e');
  }

  setState(() => _isProcessing = false);
}

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    await _processAndNavigate(File(picked.path));
    setState(() => _isProcessing = false);
  }

  Future<void> _processAndNavigate(File imageFile) async {
    // OCR
    final ocrResult = await OcrService.recognizeFromFile(
      imageFile,
      _sourceLang.ocrScript,
    );

    if (!ocrResult.hasText) {
      _showError('No text found in image. Try better lighting.');
      return;
    }

    // Translate each block
    final translatedBlocks = <TranslatedBlock>[];
    for (final block in ocrResult.blocks) {
      final result = await TranslationService.translate(
        text: block.text,
        source: _sourceLang,
        target: _targetLang,
      );
      translatedBlocks.add(TranslatedBlock(
        originalBlock: block,
        translatedText: result.translatedText,
      ));
    }

    // Also translate full text
    final fullTranslation = await TranslationService.translate(
      text: ocrResult.fullText,
      source: _sourceLang,
      target: _targetLang,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imageFile: imageFile,
          ocrResult: ocrResult,
          translatedBlocks: translatedBlocks,
          fullTranslation: fullTranslation.translatedText,
          translationMethod: fullTranslation.method,
          sourceLang: _sourceLang,
          targetLang: _targetLang,
        ),
      ),
    );
  }

  // ─── LIVE MODE ───────────────────────────────────────────────
  void _toggleLiveMode() {
    setState(() {
      _isLiveMode = !_isLiveMode;
      _liveText = '';
    });

    if (_isLiveMode) {
      _controller?.startImageStream(_processLiveFrame);
    } else {
      _controller?.stopImageStream();
    }
  }

  Future<void> _processLiveFrame(CameraImage cameraImage) async {
    if (_isLiveProcessing) return;
    _isLiveProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            cameraImage.width.toDouble(),
            cameraImage.height.toDouble(),
          ),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv_420_888,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        ),
      );

      final ocrResult = await OcrService.recognizeFromCameraImage(
        inputImage,
        _sourceLang.ocrScript,
      );

      if (ocrResult.hasText && mounted) {
        // Translate live text
        final tr = await TranslationService.translate(
          text: ocrResult.fullText,
          source: _sourceLang,
          target: _targetLang,
        );
        if (mounted) {
          setState(() => _liveText = tr.translatedText);
        }
      } else if (mounted) {
        setState(() => _liveText = '');
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 800));
    _isLiveProcessing = false;
  }

  void _toggleFlash() async {
    _flashOn = !_flashOn;
    await _controller?.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
    setState(() {});
  }

  void _swapLanguages() {
    setState(() {
      final tmp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = tmp;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          _buildCameraPreview(),

          // Top bar
          _buildTopBar(),

          // Language bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: _buildLanguageBar(),
          ),

          // Scanner overlay (live mode)
          if (_isLiveMode)
            Positioned.fill(child: ScannerOverlay(isScanning: _isLiveMode)),

          // Live translation result
          if (_isLiveMode && _liveText.isNotEmpty)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: _buildLiveTranslationBubble(),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),

          // Processing indicator
          if (_isProcessing)
            Positioned.fill(child: _buildProcessingOverlay()),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return SizedBox.expand(
      child: CameraPreview(_controller!),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // App title
            const Text(
              '🔍 Lens Translate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Flash
            _iconButton(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              _toggleFlash,
              _flashOn ? Colors.yellow : Colors.white,
            ),
            const SizedBox(width: 8),
            // Live mode toggle
            GestureDetector(
              onTap: _toggleLiveMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isLiveMode
                      ? const Color(0xFF4285F4)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isLiveMode ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isLiveMode ? 'LIVE' : 'LIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Source language
            Expanded(
              child: GestureDetector(
                onTap: () => LanguageSelectorSheet.show(
                  context,
                  selected: _sourceLang,
                  title: 'Translate From',
                  onSelected: (l) => setState(() => _sourceLang = l),
                ),
                child: _langChip(_sourceLang),
              ),
            ),

            // Swap button
            GestureDetector(
              onTap: _swapLanguages,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
              ),
            ),

            // Target language
            Expanded(
              child: GestureDetector(
                onTap: () => LanguageSelectorSheet.show(
                  context,
                  selected: _targetLang,
                  title: 'Translate To',
                  onSelected: (l) => setState(() => _targetLang = l),
                ),
                child: _langChip(_targetLang),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langChip(AppLanguage lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(lang.flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            lang.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.expand_more, color: Colors.white54, size: 16),
      ],
    );
  }

  Widget _buildLiveTranslationBubble() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Color(0xFF4285F4), size: 16),
              const SizedBox(width: 6),
              Text(
                '${_targetLang.flag} ${_targetLang.name}',
                style: const TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _liveText,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
        left: 40,
        right: 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery
          _bottomButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _pickFromGallery,
          ),

          // Capture button
          GestureDetector(
            onTap: _isLiveMode ? null : _captureAndTranslate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLiveMode ? Colors.grey : Colors.white,
                border: Border.all(
                  color: const Color(0xFF4285F4),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4285F4).withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                color: _isLiveMode ? Colors.grey.shade400 : const Color(0xFF4285F4),
                size: 30,
              ),
            ),
          ),

          // Translate text manually
          _bottomButton(
            icon: Icons.text_fields,
            label: 'Text',
            onTap: () {
              // Could open text input screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4285F4)),
            SizedBox(height: 16),
            Text(
              'Scanning & Translating...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _bottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
