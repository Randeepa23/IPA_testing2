// lib/services/ocr_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../Models/language_model.dart';

class OcrService {
  static final Map<TextScript, TextRecognizer> _recognizers = {};

  static TextRecognizer _getRecognizer(TextScript script) {
    if (!_recognizers.containsKey(script)) {
      TextRecognitionScript mlKitScript;
      switch (script) {
        case TextScript.devanagari:
          mlKitScript = TextRecognitionScript.devanagiri;
          break;
        case TextScript.chinese:
          mlKitScript = TextRecognitionScript.chinese;
          break;
        case TextScript.japanese:
          mlKitScript = TextRecognitionScript.japanese;
          break;
        case TextScript.korean:
          mlKitScript = TextRecognitionScript.korean;
          break;
        case TextScript.latin:
        default:
          mlKitScript = TextRecognitionScript.latin;
          break;
      }
      _recognizers[script] = TextRecognizer(script: mlKitScript);
    }
    return _recognizers[script]!;
  }

  // ─── MAIN: Recognize from file ────────────────────────────────
  // Strategy: ALWAYS run BOTH Latin + Devanagari, then merge all blocks.
  // Also run CJK scripts if needed.
  // This ensures mixed documents (Hindi paragraphs + English headers) are
  // fully captured.
  static Future<OcrResult> recognizeFromFile(
    File imageFile,
    TextScript script, // not used - we always run multi-script
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);

      // Always run Latin (English, numbers, French, German, etc.)
      final latinResult = await _processImage(inputImage, TextScript.latin);
      debugPrint('Latin OCR: ${latinResult.blocks.length} blocks, ${latinResult.fullText.length} chars');

      // Always run Devanagari (Hindi, Marathi, Nepali, Tamil, Sinhala)
      final devanagariResult = await _processImage(inputImage, TextScript.devanagari);
      debugPrint('Devanagari OCR: ${devanagariResult.blocks.length} blocks, ${devanagariResult.fullText.length} chars');

      // Check if we need CJK scripts
      final needsChinese = _hasScript(latinResult.fullText, 'chinese') ||
          _hasScript(devanagariResult.fullText, 'chinese');
      final needsJapanese = _hasScript(latinResult.fullText, 'japanese') ||
          _hasScript(devanagariResult.fullText, 'japanese');
      final needsKorean = _hasScript(latinResult.fullText, 'korean') ||
          _hasScript(devanagariResult.fullText, 'korean');

      final allBlocks = <TextBlock>[
        ...devanagariResult.blocks, // Devanagari first (higher priority)
        ...latinResult.blocks,
      ];

      // Add CJK if needed
      if (needsChinese) {
        final r = await _processImage(inputImage, TextScript.chinese);
        allBlocks.addAll(r.blocks);
        debugPrint('Chinese OCR: ${r.blocks.length} blocks');
      }
      if (needsJapanese) {
        final r = await _processImage(inputImage, TextScript.japanese);
        allBlocks.addAll(r.blocks);
        debugPrint('Japanese OCR: ${r.blocks.length} blocks');
      }
      if (needsKorean) {
        final r = await _processImage(inputImage, TextScript.korean);
        allBlocks.addAll(r.blocks);
        debugPrint('Korean OCR: ${r.blocks.length} blocks');
      }

      // Remove duplicate blocks (same bounding box area from multiple passes)
      final uniqueBlocks = _deduplicateBlocks(allBlocks);
      debugPrint('After dedup: ${uniqueBlocks.length} unique blocks');

      // Sort blocks top-to-bottom, left-to-right (reading order)
      uniqueBlocks.sort((a, b) {
        if (a.boundingBox == null || b.boundingBox == null) return 0;
        final topDiff = (a.boundingBox.top as double) - (b.boundingBox.top as double);
        if (topDiff.abs() > 20) return topDiff.sign.toInt();
        return ((a.boundingBox.left as double) - (b.boundingBox.left as double)).sign.toInt();
      });

      final fullText = uniqueBlocks.map((b) => b.text).join('\n');

      // If we got nothing, return the best single result
      if (uniqueBlocks.isEmpty) {
        if (devanagariResult.hasText) return devanagariResult;
        return latinResult;
      }

      return OcrResult(
        fullText: fullText,
        blocks: uniqueBlocks,
        error: null,
      );
    } catch (e) {
      debugPrint('OCR error: $e');
      return OcrResult(fullText: '', blocks: [], error: e.toString());
    }
  }

  // ─── Script detection helpers ─────────────────────────────────
  static bool _hasScript(String text, String script) {
    switch (script) {
      case 'chinese':
        return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text) &&
            !RegExp(r'[\u3040-\u30FF]').hasMatch(text);
      case 'japanese':
        return RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text);
      case 'korean':
        return RegExp(r'[\uAC00-\uD7AF]').hasMatch(text);
      default:
        return false;
    }
  }

  // ─── Remove overlapping duplicate blocks ─────────────────────
  // When Latin and Devanagari both scan the same region, keep only one
  static List<TextBlock> _deduplicateBlocks(List<TextBlock> blocks) {
    final unique = <TextBlock>[];

    for (final block in blocks) {
      if (block.text.trim().isEmpty) continue;

      bool isDuplicate = false;
      for (final existing in unique) {
        if (_blocksOverlap(block.boundingBox, existing.boundingBox)) {
          isDuplicate = true;
          // Keep the one with more text content (prefer Devanagari text over
          // garbled Latin attempt to read Hindi)
          if (block.text.length > existing.text.length) {
            unique.remove(existing);
            unique.add(block);
          }
          break;
        }
      }
      if (!isDuplicate) unique.add(block);
    }

    return unique;
  }

  static bool _blocksOverlap(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    try {
      final double overlapLeft =
          (a.left as double) > (b.left as double) ? (a.left as double) : (b.left as double);
      final double overlapTop =
          (a.top as double) > (b.top as double) ? (a.top as double) : (b.top as double);
      final double overlapRight =
          (a.right as double) < (b.right as double) ? (a.right as double) : (b.right as double);
      final double overlapBottom =
          (a.bottom as double) < (b.bottom as double) ? (a.bottom as double) : (b.bottom as double);

      if (overlapRight <= overlapLeft || overlapBottom <= overlapTop) return false;

      final overlapArea = (overlapRight - overlapLeft) * (overlapBottom - overlapTop);
      final aArea = ((a.right as double) - (a.left as double)) *
          ((a.bottom as double) - (a.top as double));

      return aArea > 0 && (overlapArea / aArea) > 0.4;
    } catch (_) {
      return false;
    }
  }

  // ─── Live camera frame (single script, fast) ─────────────────
  static Future<OcrResult> recognizeFromCameraImage(
    InputImage inputImage,
    TextScript script,
  ) async {
    try {
      // For live mode: run Latin first, add Devanagari if needed
      final latinResult = await _processImage(inputImage, TextScript.latin);

      // Quick check: if Devanagari chars found in latin result, add devanagari pass
      final hasDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(latinResult.fullText);

      if (hasDevanagari) {
        final devResult = await _processImage(inputImage, TextScript.devanagari);
        final merged = _deduplicateBlocks([...devResult.blocks, ...latinResult.blocks]);
        return OcrResult(
          fullText: merged.map((b) => b.text).join('\n'),
          blocks: merged,
          error: null,
        );
      }

      return latinResult;
    } catch (e) {
      return OcrResult(fullText: '', blocks: [], error: e.toString());
    }
  }

  // ─── Core: process one image with one script ──────────────────
  static Future<OcrResult> _processImage(
    InputImage inputImage,
    TextScript script,
  ) async {
    final recognizer = _getRecognizer(script);
    final RecognizedText result = await recognizer.processImage(inputImage);

    final blocks = result.blocks.map((block) {
      return TextBlock(
        text: block.text,
        boundingBox: block.boundingBox,
        lines: block.lines.map((line) {
          return TextLineData(
            text: line.text,
            boundingBox: line.boundingBox,
          );
        }).toList(),
      );
    }).toList();

    return OcrResult(
      fullText: result.text,
      blocks: blocks,
      error: null,
    );
  }

  static void dispose() {
    for (final r in _recognizers.values) {
      r.close();
    }
    _recognizers.clear();
  }
}

// ─── Models ───────────────────────────────────────────────────

class OcrResult {
  final String fullText;
  final List<TextBlock> blocks;
  final String? error;

  OcrResult({
    required this.fullText,
    required this.blocks,
    this.error,
  });

  bool get hasText => fullText.trim().isNotEmpty;
  bool get hasError => error != null;

  /// Returns blocks that contain significant non-Latin content.
  /// Pure English/number blocks like "CHINA POST" return false.
  /// Hindi/Chinese/Japanese blocks return true.
  List<TextBlock> get nonEnglishBlocks {
    return blocks.where((block) {
      final text = block.text.trim();
      if (text.isEmpty) return false;

      final nonEnglishChars =
          text.replaceAll(RegExp(r'[a-zA-Z0-9\s\.,!?;:()\-_/\\#@$%&*+=<>]'), '').length;
      final totalChars = text.replaceAll(RegExp(r'\s'), '').length;

      if (totalChars == 0) return false;

      // Keep block if at least 20% of chars are non-Latin
      // This captures:
      //   Hindi "आपका विद्यालय" = 100% non-Latin ✅
      //   Mixed "35. छुट्टी" = ~80% non-Latin ✅
      //   Pure English "CHINA POST" = 0% ❌ skipped
      //   Numbers only "110003" = 0% ❌ skipped
      return (nonEnglishChars / totalChars) > 0.20;
    }).toList();
  }
}

class TextBlock {
  final String text;
  final dynamic boundingBox;
  final List<TextLineData> lines;

  TextBlock({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });
}

class TextLineData {
  final String text;
  final dynamic boundingBox;

  TextLineData({required this.text, required this.boundingBox});
}