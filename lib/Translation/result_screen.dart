// lib/screens/result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/language_model.dart';
import '../Services/ocr_service.dart';
import '../ui/widgets/translation_overlay.dart';

// ── Shared colours (aligned with Leave / Vehicle modules) ────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kPrimaryLight = Color(0xFF2B7DE9);
const _kBg = Colors.white;
const _kSurface = Color(0xFFF8FAFF);
const _kBorder = Color(0xFFE1E6EF);
const _kTextPrimary = Color(0xFF1E2A3A);
const _kTextSecondary = Color(0xFF6B7A90);
const _kCardShadow = Color(0x0F000000); // ~6 % black

class ResultScreen extends StatefulWidget {
  final File imageFile;
  final OcrResult ocrResult;
  final List<TranslatedBlock> translatedBlocks;
  final String fullTranslation;
  final String translationMethod;
  final AppLanguage sourceLang;
  final AppLanguage targetLang;
  final String? detectedLanguage;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.ocrResult,
    required this.translatedBlocks,
    required this.fullTranslation,
    required this.translationMethod,
    required this.sourceLang,
    required this.targetLang,
    this.detectedLanguage,
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
    } catch (_) {
      if (mounted) setState(() => _imageSize = const Size(1080, 1920));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: _kPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (widget.sourceLang.code == 'auto' &&
              widget.detectedLanguage != null)
            _buildDetectedBanner(),
          _buildTabBar(),
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

  // ── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final sourceDisplay = widget.sourceLang.code == 'auto'
        ? '🔍 Auto'
        : '${widget.sourceLang.flag} ${widget.sourceLang.name}';

    return AppBar(
      backgroundColor: _kBg,
      elevation: 0,
      foregroundColor: _kTextPrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        color: _kTextPrimary,
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Text(sourceDisplay,
              style: const TextStyle(color: _kTextSecondary, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, color: _kPrimary, size: 15),
          ),
          Text(widget.targetLang.flag,
              style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 4),
          Text(widget.targetLang.name,
              style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        if (widget.translationMethod.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _Chip(
                label: widget.translationMethod,
                bg: const Color(0xFFEAF1FF),
                fg: _kPrimary,
              ),
            ),
          ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _kBorder),
      ),
    );
  }

  // ── Detected-language banner ─────────────────────────────────────────────
  Widget _buildDetectedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: const Color(0xFFEAF1FF),
      child: Row(
        children: [
          const Icon(Icons.language, color: _kPrimary, size: 15),
          const SizedBox(width: 8),
          Text(
            'Detected: ${widget.detectedLanguage}',
            style: const TextStyle(
                color: _kPrimary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward, color: _kPrimaryLight, size: 13),
          const SizedBox(width: 4),
          Text(widget.targetLang.name,
              style: const TextStyle(color: _kTextSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Pill-style tab bar (matches Leave / Vehicle filter chips) ────────────
  Widget _buildTabBar() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => Row(
          children: List.generate(3, (i) {
            final labels = ['Overlay', 'Translation', 'Original'];
            final icons = [
              Icons.layers_outlined,
              Icons.translate,
              Icons.text_snippet_outlined,
            ];
            final active = _tabController.index == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => _tabController.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? _kPrimary : _kSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: active ? _kPrimary : _kBorder, width: 1.2),
                    boxShadow: active
                        ? [
                            BoxShadow(
                                color: _kPrimary.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icons[i],
                          size: 13,
                          color: active ? Colors.white : _kTextSecondary),
                      const SizedBox(width: 5),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── TAB 1 – Overlay ──────────────────────────────────────────────────────
  Widget _buildOverlayTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // image + overlay stack inside a card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _card(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(widget.imageFile,
                        width: double.infinity, fit: BoxFit.fitWidth),
                  ),
                  // toggle button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showOverlay = !_showOverlay),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: _kBorder),
                          boxShadow: const [
                            BoxShadow(
                                color: _kCardShadow,
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showOverlay
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: _kPrimary,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showOverlay ? 'Hide' : 'Show',
                              style: const TextStyle(
                                  color: _kPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // translation overlay painter
                  if (_showOverlay)
                    Positioned.fill(
                      child: _imageSize == null
                          ? const SizedBox.shrink()
                          : LayoutBuilder(builder: (ctx, constraints) {
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
                            }),
                    ),
                ],
              ),
            ),
          ),
          // info row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: _kTextSecondary, size: 13),
                const SizedBox(width: 6),
                const Text('Translated text overlaid on original',
                    style: TextStyle(color: _kTextSecondary, fontSize: 11)),
                const Spacer(),
                _Chip(
                  label: '${widget.translatedBlocks.length} blocks',
                  bg: const Color(0xFFEAF1FF),
                  fg: _kPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── TAB 2 – Translation ──────────────────────────────────────────────────
  Widget _buildTranslationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // block-by-block cards
          ...widget.translatedBlocks.asMap().entries.map((e) =>
              _buildTranslationCard(
                original: e.value.originalBlock.text,
                translated: e.value.translatedText,
                index: e.key + 1,
              )),
          const SizedBox(height: 8),
          // full translation card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.translate,
                          color: _kPrimary, size: 15),
                    ),
                    const SizedBox(width: 10),
                    const Text('Full Translation',
                        style: TextStyle(
                            color: _kTextPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    const Spacer(),
                    _iconButton(
                      icon: Icons.copy_outlined,
                      tooltip: 'Copy',
                      onTap: () => _copy(widget.fullTranslation),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: _kBorder, height: 1),
                const SizedBox(height: 12),
                SelectableText(
                  widget.fullTranslation,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 15,
                    height: 1.65,
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
    final sourceLangLabel = widget.sourceLang.code == 'auto'
        ? (widget.detectedLanguage ?? '🔍 Detected')
        : '${widget.sourceLang.flag} ${widget.sourceLang.name}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header strip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$index',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Text(sourceLangLabel,
                      style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // original text
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(original,
                  style: const TextStyle(
                      color: _kTextSecondary, fontSize: 13, height: 1.5)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(color: _kBorder, height: 1),
            ),
            // translated text
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.targetLang.flag,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(widget.targetLang.name,
                          style: const TextStyle(
                              color: _kPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    translated,
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        noPadding: true,
      ),
    );
  }

  // ── TAB 3 – Original ─────────────────────────────────────────────────────
  Widget _buildOriginalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.sourceLang.code == 'auto'
                      ? '🔍'
                      : widget.sourceLang.flag,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.sourceLang.code == 'auto'
                      ? 'Detected: ${widget.detectedLanguage ?? "Auto"}'
                      : 'Original ${widget.sourceLang.name} Text',
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _iconButton(
                icon: Icons.copy_outlined,
                tooltip: 'Copy original',
                onTap: () => _copy(widget.ocrResult.fullText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // original text card
          _card(
            child: SelectableText(
              widget.ocrResult.fullText,
              style: const TextStyle(
                  color: _kTextPrimary, fontSize: 14, height: 1.7),
            ),
          ),
          const SizedBox(height: 14),
          // image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(widget.imageFile, width: double.infinity),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  /// Standard white card with shadow matching Leave / Vehicle modules.
  Widget _card({required Widget child, bool noPadding = false}) {
    return Container(
      width: double.infinity,
      padding: noPadding ? EdgeInsets.zero : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Icon(icon, size: 16, color: _kTextSecondary),
        ),
      ),
    );
  }
}

// ── Reusable pill chip ───────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
