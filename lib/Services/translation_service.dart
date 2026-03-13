// lib/services/translation_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import '../Models/language_model.dart';

class TranslationService {
  static final Map<String, OnDeviceTranslator> _translators = {};
  static final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  static final LanguageIdentifier _langIdentifier =
      LanguageIdentifier(confidenceThreshold: 0.3);

  // ─── MAIN ENTRY ──────────────────────────────────────────────
  static Future<TranslationResult> translate({
    required String text,
    required AppLanguage source,
    required AppLanguage target,
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult(
          translatedText: '', method: '', detectedLanguage: null);
    }

    String actualSourceCode = source.code;
    String? detectedLangName;

    // ── Step 1: Detect language if auto ──────────────────────
    if (source.code == 'auto') {
      final detected = await _detectLanguageMLKit(text);
      actualSourceCode = detected;

      debugPrint('Detected language: $actualSourceCode for text: ${text.substring(0, text.length.clamp(0, 50))}');

      // If detected as English AND target is also English → skip
      if (actualSourceCode == 'en' && target.code == 'en') {
        return TranslationResult(
          translatedText: text,
          method: '✓ English',
          detectedLanguage: 'en',
        );
      }

      // If detected as English but target is different language → translate English to target
      // Don't skip, fall through to translation below

      final detectedLang = findByCode(actualSourceCode);
      detectedLangName = detectedLang != null
          ? '${detectedLang.flag} ${detectedLang.name}'
          : actualSourceCode.toUpperCase();
    }

    // ── Step 2: Don't translate if source == target ───────────
    if (actualSourceCode == target.code) {
      return TranslationResult(
        translatedText: text,
        method: '✓ Same language',
        detectedLanguage: detectedLangName,
      );
    }

    // ── Step 3: Resolve the actual source AppLanguage ─────────
    final resolvedSource = source.code == 'auto'
        ? (findByCode(actualSourceCode) ??
            AppLanguage(
              code: actualSourceCode,
              mlKitCode: actualSourceCode,
              name: actualSourceCode,
              nativeName: actualSourceCode,
              flag: '🌐',
              offlineSupported: false,
              ocrScript: TextScript.latin,
            ))
        : source;

    // ── Step 4: Try ML Kit on-device first (offline, fast) ────
    if (resolvedSource.offlineSupported && target.offlineSupported) {
      final result = await _translateOnDevice(text, resolvedSource, target);
      if (result != null) {
        return TranslationResult(
          translatedText: result.translatedText,
          method: result.method,
          detectedLanguage: detectedLangName,
        );
      }
    }

    // ── Step 5: MyMemory API fallback ─────────────────────────
    final result = await _translateMyMemory(text, actualSourceCode, target);
    return TranslationResult(
      translatedText: result.translatedText,
      method: result.method,
      detectedLanguage: detectedLangName,
    );
  }

  // ─── ML KIT LANGUAGE IDENTIFICATION ─────────────────────────
  static Future<String> _detectLanguageMLKit(String text) async {
    try {
      final sample =
          text.trim().substring(0, text.trim().length.clamp(0, 200));

      final String response = await _langIdentifier.identifyLanguage(sample);

      if (response != 'und' && response.isNotEmpty) {
        debugPrint('ML Kit identified: $response');
        return response.toLowerCase().split('-')[0];
      }

      final List<IdentifiedLanguage> possibilities =
          await _langIdentifier.identifyPossibleLanguages(sample);

      if (possibilities.isNotEmpty) {
        possibilities.sort((a, b) => b.confidence.compareTo(a.confidence));
        final best = possibilities.first;
        debugPrint(
            'ML Kit best guess: ${best.languageTag} (${best.confidence})');
        return best.languageTag.toLowerCase().split('-')[0];
      }
    } catch (e) {
      debugPrint('ML Kit language ID error: $e');
    }

    // Unicode-based fallback detection
    return _guessLanguageFromChars(text);
  }

  static String _guessLanguageFromChars(String text) {
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) return 'ja';
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text) &&
        !RegExp(r'[\u3040-\u30FF]').hasMatch(text)) return 'zh';
    if (RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]').hasMatch(text)) return 'ko';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return 'ar';
    if (RegExp(r'[\u0E00-\u0E7F]').hasMatch(text)) return 'th';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi';
    if (RegExp(r'[\u0D80-\u0DFF]').hasMatch(text)) return 'si';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'ta';
    if (RegExp(r'[\u0400-\u04FF]').hasMatch(text)) return 'ru';
    return 'en';
  }

  // ─── ON-DEVICE TRANSLATION (ML Kit) ──────────────────────────
  static Future<TranslationResult?> _translateOnDevice(
    String text,
    AppLanguage source,
    AppLanguage target,
  ) async {
    try {
      final key = '${source.mlKitCode}_${target.mlKitCode}';

      if (!_translators.containsKey(key)) {
        TranslateLanguage sourceLang;
        TranslateLanguage targetLang;
        try {
          sourceLang = TranslateLanguage.values
              .firstWhere((l) => l.bcpCode == source.mlKitCode);
          targetLang = TranslateLanguage.values
              .firstWhere((l) => l.bcpCode == target.mlKitCode);
        } catch (_) {
          return null;
        }
        _translators[key] = OnDeviceTranslator(
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
        );
      }

      final sourceLang = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == source.mlKitCode,
        orElse: () => TranslateLanguage.english,
      );
      final targetLang = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == target.mlKitCode,
        orElse: () => TranslateLanguage.english,
      );

      if (!await _modelManager.isModelDownloaded(sourceLang as String)) {
        await _modelManager.downloadModel(sourceLang as String);
      }
      if (!await _modelManager.isModelDownloaded(targetLang as String)) {
        await _modelManager.downloadModel(targetLang as String);
      }

      final translated = await _translators[key]!.translateText(text);
      return TranslationResult(
          translatedText: translated,
          method: '📱 Offline',
          detectedLanguage: null);
    } catch (e) {
      debugPrint('On-device translation error: $e');
      return null;
    }
  }

  // ─── MYMEMORY API ─────────────────────────────────────────────
  static Future<TranslationResult> _translateMyMemory(
    String text,
    String sourceCode,
    AppLanguage target,
  ) async {
    try {
      final chunks = _chunkText(text, 400);
      final translatedChunks = <String>[];

      for (final chunk in chunks) {
        final encodedText = Uri.encodeComponent(chunk);
        final url = 'https://api.mymemory.translated.net/get'
            '?q=$encodedText'
            '&langpair=$sourceCode|${target.code}';

        debugPrint('MyMemory request: $sourceCode → ${target.code}');

        final response = await http
            .get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        debugPrint('MyMemory status: ${response.statusCode}');
        debugPrint('MyMemory body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final translated =
              data['responseData']?['translatedText'] as String?;
          if (translated != null && translated.isNotEmpty) {
            // MyMemory sometimes returns error messages as translated text
            if (translated.contains('PLEASE SELECT') ||
                translated.contains('MYMEMORY') ||
                translated.contains('QUOTA')) {
              debugPrint('MyMemory quota error: $translated');
              // Try with 'hi' as explicit source for Hindi if auto detected
              continue;
            }
            translatedChunks.add(translated);
          }
        }
      }

      if (translatedChunks.isNotEmpty) {
        return TranslationResult(
          translatedText: translatedChunks.join(' '),
          method: '🌐 Online',
          detectedLanguage: null,
        );
      }

      // All chunks failed
      return TranslationResult(
        translatedText: 'Translation failed. Please check your internet connection.',
        method: '❌ Failed',
        detectedLanguage: null,
      );
    } catch (e) {
      debugPrint('MyMemory error: $e');
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        return TranslationResult(
          translatedText: 'No internet connection. Please connect to WiFi or mobile data.',
          method: '❌ No internet',
          detectedLanguage: null,
        );
      }
      return TranslationResult(
          translatedText: 'Translation error: $e',
          method: '❌ Error',
          detectedLanguage: null);
    }
  }

  static bool isEnglish(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return true;
    final englishChars = cleaned.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    final totalChars = cleaned.replaceAll(RegExp(r'\s'), '').length;
    if (totalChars == 0) return true;
    return (englishChars / totalChars) > 0.70;
  }

  static List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      final end =
          (start + maxLen < text.length) ? start + maxLen : text.length;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  static void dispose() {
    _langIdentifier.close();
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}

class TranslationResult {
  final String translatedText;
  final String method;
  final String? detectedLanguage;

  TranslationResult({
    required this.translatedText,
    required this.method,
    required this.detectedLanguage,
  });
}