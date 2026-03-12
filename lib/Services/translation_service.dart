// lib/services/translation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../Models/language_model.dart';

class TranslationService {
  static final Map<String, OnDeviceTranslator> _translators = {};
  static final ModelManager _modelManager = OnDeviceTranslatorModelManager();

  /// Main translation entry point
  /// Uses ML Kit offline for supported languages, falls back to MyMemory API
  static Future<TranslationResult> translate({
    required String text,
    required AppLanguage source,
    required AppLanguage target,
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult(translatedText: '', method: '');
    }

    // Try ML Kit on-device first (fast, offline, free)
    if (source.offlineSupported && target.offlineSupported) {
      final result = await _translateOnDevice(text, source, target);
      if (result != null) return result;
    }

    // Fallback: MyMemory API (free, 5000 chars/day, supports Sinhala)
    return await _translateMyMemory(text, source, target);
  }

  // ─── ON-DEVICE (ML Kit) ──────────────────────────────────────
  static Future<TranslationResult?> _translateOnDevice(
    String text,
    AppLanguage source,
    AppLanguage target,
  ) async {
    try {
      final key = '${source.mlKitCode}_${target.mlKitCode}';

      if (!_translators.containsKey(key)) {
        final sourceLang = TranslateLanguage.values.firstWhere(
          (l) => l.bcpCode == source.mlKitCode,
          orElse: () => TranslateLanguage.english,
        );
        final targetLang = TranslateLanguage.values.firstWhere(
          (l) => l.bcpCode == target.mlKitCode,
          orElse: () => TranslateLanguage.english,
        );

        _translators[key] = OnDeviceTranslator(
          sourceLanguage: sourceLang,
          targetLanguage: targetLang,
        );
      }

      // Ensure models are downloaded
      final sourceLangModel = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == source.mlKitCode,
        orElse: () => TranslateLanguage.english,
      );
      final targetLangModel = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == target.mlKitCode,
        orElse: () => TranslateLanguage.english,
      );

      final sourceDownloaded = await _modelManager.isModelDownloaded(sourceLangModel as String);
      final targetDownloaded = await _modelManager.isModelDownloaded(targetLangModel as String);

      if (!sourceDownloaded) {
        await _modelManager.downloadModel(sourceLangModel as String);
      }
      if (!targetDownloaded) {
        await _modelManager.downloadModel(targetLangModel as String);
      }

      final translated = await _translators[key]!.translateText(text);
      return TranslationResult(translatedText: translated, method: '📱 Offline');
    } catch (e) {
      return null; // Fall through to online API
    }
  }

  // ─── MYMEMORY API (Free, online, supports Sinhala) ───────────
  static Future<TranslationResult> _translateMyMemory(
    String text,
    AppLanguage source,
    AppLanguage target,
  ) async {
    try {
      // Chunk text if it's too long (MyMemory has ~500 char limit per request)
      final chunks = _chunkText(text, 400);
      final translatedChunks = <String>[];

      for (final chunk in chunks) {
        final encodedText = Uri.encodeComponent(chunk);
        final url = 'https://api.mymemory.translated.net/get'
            '?q=$encodedText'
            '&langpair=${source.code}|${target.code}';

        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final translated = data['responseData']?['translatedText'] as String?;
          if (translated != null) {
            translatedChunks.add(translated);
          }
        }
      }

      if (translatedChunks.isNotEmpty) {
        return TranslationResult(
          translatedText: translatedChunks.join(' '),
          method: '🌐 Online',
        );
      }

      return TranslationResult(
        translatedText: 'Translation failed. Check internet connection.',
        method: '',
      );
    } catch (e) {
      return TranslationResult(
        translatedText: 'Error: $e',
        method: '',
      );
    }
  }

  // ─── LIBRETRANSLATE (Alternative free API, self-hostable) ────
  // Uncomment to use LibreTranslate instead of MyMemory
  // static Future<TranslationResult> _translateLibre(
  //   String text, AppLanguage source, AppLanguage target,
  // ) async {
  //   final response = await http.post(
  //     Uri.parse('https://libretranslate.com/translate'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'q': text,
  //       'source': source.code,
  //       'target': target.code,
  //       'format': 'text',
  //       // 'api_key': 'YOUR_KEY_IF_NEEDED', // optional for self-hosted
  //     }),
  //   );
  //   final data = jsonDecode(response.body);
  //   return TranslationResult(
  //     translatedText: data['translatedText'] ?? '',
  //     method: '🌐 LibreTranslate',
  //   );
  // }

  static List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      final end = (start + maxLen < text.length) ? start + maxLen : text.length;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  static void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}

class TranslationResult {
  final String translatedText;
  final String method; // 'Offline' or 'Online'

  TranslationResult({required this.translatedText, required this.method});
}
