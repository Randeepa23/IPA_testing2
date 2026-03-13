// lib/screens/camera_screen.dart

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' hide TextBlock;
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
  bool _isLiveMode = false;
  bool _flashOn = false;

  AppLanguage _sourceLang = kAutoDetect;
  AppLanguage _targetLang = kLanguages[0]; // English default

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

  // ─── CAPTURE ─────────────────────────────────────────────────
  Future<void> _captureAndTranslate() async {
    if (!_isInitialized || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      HapticFeedback.mediumImpact();
      final image = await _controller!.takePicture();
      await _processAndNavigate(File(image.path));
    } catch (e) {
      _showError('Capture failed: $e');
    }

    setState(() => _isProcessing = false);
  }

  // ─── GALLERY ─────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    await _processAndNavigate(File(picked.path));
    setState(() => _isProcessing = false);
  }

  // ─── CORE: OCR + TRANSLATE + NAVIGATE ────────────────────────
  Future<void> _processAndNavigate(File imageFile) async {
    // Step 1: Run OCR (auto-detects script internally)
    final ocrResult = await OcrService.recognizeFromFile(
      imageFile,
      TextScript.latin,
    );

    if (!ocrResult.hasText) {
      _showError('No text found in image. Try better lighting.');
      return;
    }

    debugPrint('OCR found ${ocrResult.blocks.length} blocks');
    debugPrint('OCR full text: ${ocrResult.fullText.substring(0, ocrResult.fullText.length.clamp(0, 100))}');

    // Step 2: Pick blocks to translate
    // - Source is English → translate ALL blocks
    // - Source is auto/other → skip pure English blocks (numbers, English words)
    List<TextBlock> blocksToTranslate;

    if (_sourceLang.code == 'en') {
      // User explicitly chose English source → translate everything
      blocksToTranslate = ocrResult.blocks;
    } else {
      // Filter: keep blocks that have significant non-English content
      final filtered = ocrResult.nonEnglishBlocks;
      debugPrint('After filter: ${filtered.length} non-English blocks');

      // Safety fallback: if filter removed everything, use ALL blocks
      // This is important for Hindi/auto where everything might be non-Latin
      blocksToTranslate = filtered.isEmpty ? ocrResult.blocks : filtered;
    }

    // Step 3: Translate each block
    final translatedBlocks = <TranslatedBlock>[];
    String? detectedLangDisplay;

    for (final block in blocksToTranslate) {
      debugPrint('Translating block: "${block.text.substring(0, block.text.length.clamp(0, 50))}"');

      final result = await TranslationService.translate(
        text: block.text,
        source: _sourceLang,
        target: _targetLang,
      );

      debugPrint('Result: "${result.translatedText.substring(0, result.translatedText.length.clamp(0, 50))}" method: ${result.method}');

      // Capture detected language from first block that has it
      if (detectedLangDisplay == null && result.detectedLanguage != null) {
        detectedLangDisplay = result.detectedLanguage;
      }

      // Skip failed translations and empty results
      if (result.translatedText.isEmpty) continue;
      if (result.method.contains('Failed') || result.method.contains('❌')) continue;
      // Skip if translation is same as original (means it failed silently)
      // BUT only skip for non-error cases - allow same text if it's a valid same-lang result
      if (result.method.contains('✓ Same language')) continue;

      translatedBlocks.add(TranslatedBlock(
        originalBlock: block,
        translatedText: result.translatedText,
      ));
    }

    // Step 4: Full document translation for the Translation tab
    final textForFullTranslation =
        blocksToTranslate.map((b) => b.text).join('\n');

    final fullTranslation = await TranslationService.translate(
      text: textForFullTranslation.isEmpty
          ? ocrResult.fullText
          : textForFullTranslation,
      source: _sourceLang,
      target: _targetLang,
    );

    // Step 5: Build the method display label
    final methodDisplay =
        _sourceLang.code == 'auto' && detectedLangDisplay != null
            ? '🔍 $detectedLangDisplay → ${_targetLang.name}'
            : fullTranslation.method;

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imageFile: imageFile,
          ocrResult: ocrResult,
          translatedBlocks: translatedBlocks,
          fullTranslation: fullTranslation.translatedText,
          translationMethod: methodDisplay,
          sourceLang: _sourceLang,
          targetLang: _targetLang,
          detectedLanguage: detectedLangDisplay,
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
        TextScript.latin,
      );

      if (ocrResult.hasText && mounted) {
        final liveBlocks = _sourceLang.code == 'en'
            ? ocrResult.blocks
            : ocrResult.nonEnglishBlocks.isEmpty
                ? ocrResult.blocks
                : ocrResult.nonEnglishBlocks;

        final textToTranslate = liveBlocks.map((b) => b.text).join(' ');

        if (textToTranslate.isNotEmpty) {
          final tr = await TranslationService.translate(
            text: textToTranslate,
            source: _sourceLang,
            target: _targetLang,
          );
          if (mounted && tr.translatedText.isNotEmpty &&
              !tr.method.contains('❌')) {
            setState(() => _liveText = tr.translatedText);
          }
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
          _buildCameraPreview(),
          _buildTopBar(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 0,
            right: 0,
            child: _buildLanguageBar(),
          ),
          if (_isLiveMode)
            Positioned.fill(child: ScannerOverlay(isScanning: _isLiveMode)),
          if (_isLiveMode && _liveText.isNotEmpty)
            Positioned(
              bottom: 160,
              left: 16,
              right: 16,
              child: _buildLiveTranslationBubble(),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
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
    return SizedBox.expand(child: CameraPreview(_controller!));
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
            const Text(
              '🔍 Lens Translate',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _iconButton(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              _toggleFlash,
              _flashOn ? Colors.yellow : Colors.white,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleLiveMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    const Text(
                      'LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
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
            Expanded(
              child: GestureDetector(
                onTap: () => LanguageSelectorSheet.show(
                  context,
                  selected: _sourceLang,
                  title: 'Translate From',
                  includeAutoDetect: true,
                  onSelected: (l) => setState(() => _sourceLang = l),
                ),
                child: _langChip(_sourceLang),
              ),
            ),
            GestureDetector(
              onTap: _swapLanguages,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF4285F4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz,
                    color: Colors.white, size: 18),
              ),
            ),
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
                fontSize: 13),
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
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _liveText,
            style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w500),
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
          _bottomButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _pickFromGallery,
          ),
          GestureDetector(
            onTap: _isLiveMode ? null : _captureAndTranslate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLiveMode ? Colors.grey : Colors.white,
                border:
                    Border.all(color: const Color(0xFF4285F4), width: 3),
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
                color: _isLiveMode
                    ? Colors.grey.shade400
                    : const Color(0xFF4285F4),
                size: 30,
              ),
            ),
          ),
          _bottomButton(
            icon: Icons.text_fields,
            label: 'Text',
            onTap: () {},
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
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}