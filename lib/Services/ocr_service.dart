// lib/services/ocr_service.dart

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../Models/language_model.dart';

class OcrService {
  // Cached recognizers per script type
  static final Map<TextScript, TextRecognizer> _recognizers = {};

  static TextRecognizer _getRecognizer(TextScript script) {
    if (!_recognizers.containsKey(script)) {
      TextRecognitionScript mlKitScript;
      switch (script) {
        case TextScript.devanagari:
          mlKitScript = TextRecognitionScript.latin; // ML Kit doesn't have a separate Devanagari model, it uses the Latin one for all non-Latin scripts
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
        mlKitScript = TextRecognitionScript.latin;
          break;
      }
      _recognizers[script] = TextRecognizer(script: mlKitScript);
    }
    return _recognizers[script]!;
  }

  /// Recognize text from a file (camera or gallery)
  static Future<OcrResult> recognizeFromFile(
    File imageFile,
    TextScript script,
  ) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      return await _processImage(inputImage, script);
    } catch (e) {
      return OcrResult(fullText: '', blocks: [], error: e.toString());
    }
  }

  /// Recognize text from camera stream frame
  static Future<OcrResult> recognizeFromCameraImage(
    InputImage inputImage,
    TextScript script,
  ) async {
    try {
      return await _processImage(inputImage, script);
    } catch (e) {
      return OcrResult(fullText: '', blocks: [], error: e.toString());
    }
  }

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
}

class TextBlock {
  final String text;
  final dynamic boundingBox; // Rect
  final List<TextLineData> lines;

  TextBlock({
    required this.text,
    required this.boundingBox,
    required this.lines,
  });
}

class TextLineData {
  final String text;
  final dynamic boundingBox; // Rect

  TextLineData({required this.text, required this.boundingBox});
}
