// lib/screens/result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/language_model.dart';
import '../Services/ocr_service.dart';
import '../ui/widgets/translation_overlay.dart';

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final OcrResult ocrResult;
  final List<TranslatedBlock> translatedBlocks;
  final String fullTranslation;
  final String translationMethod;
  final AppLanguage sourceLang;
  final AppLanguage targetLang;
  final String? detectedLanguage; // ← NEW: e.g. "🇯🇵 Japanese"

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.ocrResult,
    required this.translatedBlocks,
    required this.fullTranslation,
    required this.translationMethod,
    required this.sourceLang,
    required this.targetLang,
    this.detectedLanguage, // optional
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showOverlay = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadImageSize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageSize = Size(
            decodedImage.width.toDouble(),
            decodedImage.height.toDouble(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _imageSize = const Size(1080, 1920));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Show detected language banner when auto-detect was used
          if (widget.sourceLang.code == 'auto' &&
              widget.detectedLanguage != null)
            _buildDetectedLanguageBanner(),

          Container(
            color: const Color(0xFF1A1A2E),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4285F4),
              labelColor: const Color(0xFF4FC3F7),
              unselectedLabelColor: Colors.white38,
              tabs: const [
                Tab(text: 'Overlay'),
                Tab(text: 'Translation'),
                Tab(text: 'Original'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverlayTab(),
                _buildTranslationTab(),
                _buildOriginalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── DETECTED LANGUAGE BANNER ────────────────────────────────
  Widget _buildDetectedLanguageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF4285F4).withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.language, color: Color(0xFF4FC3F7), size: 16),
          const SizedBox(width: 8),
          Text(
            'Detected: ${widget.detectedLanguage}',
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward, color: Color(0xFF4285F4), size: 14),
          const SizedBox(width: 4),
          Text(
            widget.targetLang.name,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Show detected language in appbar when auto-detect mode
    final sourceDisplay = widget.sourceLang.code == 'auto'
        ? '🔍 Auto'
        : '${widget.sourceLang.flag} ${widget.sourceLang.name}';

    return AppBar(
      backgroundColor: const Color(0xFF1A1A2E),
      foregroundColor: Colors.white,
      title: Row(
        children: [
          Text(sourceDisplay,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, color: Color(0xFF4285F4), size: 16),
          ),
          Text(widget.targetLang.flag,
              style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(widget.targetLang.name,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
      actions: [
        if (widget.translationMethod.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF4285F4).withOpacity(0.5)),
                ),
                child: Text(
                  widget.translationMethod,
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7), fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── TAB 1: OVERLAY ──────────────────────────────────────────
  Widget _buildOverlayTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Stack(
            children: [
              Image.file(
                widget.imageFile,
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showOverlay = !_showOverlay),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOverlay
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showOverlay ? 'Hide' : 'Show',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showOverlay)
                Positioned.fill(
                  child: _imageSize == null
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomPaint(
                              painter: TranslationOverlayPainter(
                                blocks: widget.translatedBlocks,
                                imageSize: _imageSize!,
                                widgetSize: Size(
                                  constraints.maxWidth,
                                  constraints.maxWidth *
                                      _imageSize!.height /
                                      _imageSize!.width,
                                ),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Translated text appears over original',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${widget.translatedBlocks.length} blocks',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: TRANSLATION ──────────────────────────────────────
  Widget _buildTranslationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...widget.translatedBlocks.asMap().entries.map((entry) {
            final block = entry.value;
            return _buildTranslationCard(
              original: block.originalBlock.text,
              translated: block.translatedText,
              index: entry.key + 1,
            );
          }),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4285F4).withOpacity(0.15),
                  const Color(0xFF4FC3F7).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF4285F4).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.translate,
                        color: Color(0xFF4285F4), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Full Translation',
                      style: TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.fullTranslation));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!')),
                        );
                      },
                      child: const Icon(Icons.copy,
                          color: Colors.white38, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  widget.fullTranslation,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationCard({
    required String original,
    required String translated,
    required int index,
  }) {
    // Determine source label - show detected lang if auto mode
    final sourceLangLabel = widget.sourceLang.code == 'auto'
        ? (widget.detectedLanguage ?? '🔍 Detected')
        : '${widget.sourceLang.flag} ${widget.sourceLang.name}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A2A4A),
                  shape: BoxShape.circle,
                ),
                child: Text('$index',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Text(sourceLangLabel,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(original,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 14)),
          const Divider(color: Colors.white12, height: 16),
          Row(
            children: [
              Text(widget.targetLang.flag,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(widget.targetLang.name,
                  style: const TextStyle(
                      color: Color(0xFF4FC3F7), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            translated,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3: ORIGINAL ─────────────────────────────────────────
  Widget _buildOriginalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.sourceLang.code == 'auto'
                    ? '🔍'
                    : widget.sourceLang.flag,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                widget.sourceLang.code == 'auto'
                    ? 'Detected: ${widget.detectedLanguage ?? "Auto"}'
                    : 'Original ${widget.sourceLang.name} Text',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: widget.ocrResult.fullText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')),
                  );
                },
                child: const Icon(Icons.copy, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SelectableText(
              widget.ocrResult.fullText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(widget.imageFile, width: double.infinity),
          ),
        ],
      ),
    );
  }
}