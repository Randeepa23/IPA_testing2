// lib/models/language_model.dart

class AppLanguage {
  final String code;       // BCP-47 code for translation API
  final String mlKitCode;  // ML Kit translation model code
  final String name;
  final String nativeName;
  final String flag;
  final bool offlineSupported; // ML Kit on-device support
  final TextScript ocrScript;  // Which OCR script to use

  const AppLanguage({
    required this.code,
    required this.mlKitCode,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.offlineSupported,
    required this.ocrScript,
  });
}

enum TextScript {
  latin,
  devanagari,
  chinese,
  japanese,
  korean,
}

// All supported languages
const List<AppLanguage> kLanguages = [
  AppLanguage(
    code: 'en', mlKitCode: 'en', name: 'English', nativeName: 'English',
    flag: '🇬🇧', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'si', mlKitCode: 'si', name: 'Sinhala', nativeName: 'සිංහල',
    flag: '🇱🇰', offlineSupported: false, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'ta', mlKitCode: 'ta', name: 'Tamil', nativeName: 'தமிழ்',
    flag: '🇮🇳', offlineSupported: true, ocrScript: TextScript.devanagari,
  ),
  AppLanguage(
    code: 'hi', mlKitCode: 'hi', name: 'Hindi', nativeName: 'हिन्दी',
    flag: '🇮🇳', offlineSupported: true, ocrScript: TextScript.devanagari,
  ),
  AppLanguage(
    code: 'fr', mlKitCode: 'fr', name: 'French', nativeName: 'Français',
    flag: '🇫🇷', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'de', mlKitCode: 'de', name: 'German', nativeName: 'Deutsch',
    flag: '🇩🇪', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'es', mlKitCode: 'es', name: 'Spanish', nativeName: 'Español',
    flag: '🇪🇸', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'it', mlKitCode: 'it', name: 'Italian', nativeName: 'Italiano',
    flag: '🇮🇹', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'pt', mlKitCode: 'pt', name: 'Portuguese', nativeName: 'Português',
    flag: '🇵🇹', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'ru', mlKitCode: 'ru', name: 'Russian', nativeName: 'Русский',
    flag: '🇷🇺', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'ar', mlKitCode: 'ar', name: 'Arabic', nativeName: 'العربية',
    flag: '🇸🇦', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'zh', mlKitCode: 'zh', name: 'Chinese', nativeName: '中文',
    flag: '🇨🇳', offlineSupported: true, ocrScript: TextScript.chinese,
  ),
  AppLanguage(
    code: 'ja', mlKitCode: 'ja', name: 'Japanese', nativeName: '日本語',
    flag: '🇯🇵', offlineSupported: true, ocrScript: TextScript.japanese,
  ),
  AppLanguage(
    code: 'ko', mlKitCode: 'ko', name: 'Korean', nativeName: '한국어',
    flag: '🇰🇷', offlineSupported: true, ocrScript: TextScript.korean,
  ),
  AppLanguage(
    code: 'tr', mlKitCode: 'tr', name: 'Turkish', nativeName: 'Türkçe',
    flag: '🇹🇷', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'nl', mlKitCode: 'nl', name: 'Dutch', nativeName: 'Nederlands',
    flag: '🇳🇱', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'pl', mlKitCode: 'pl', name: 'Polish', nativeName: 'Polski',
    flag: '🇵🇱', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'th', mlKitCode: 'th', name: 'Thai', nativeName: 'ภาษาไทย',
    flag: '🇹🇭', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'vi', mlKitCode: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt',
    flag: '🇻🇳', offlineSupported: true, ocrScript: TextScript.latin,
  ),
  AppLanguage(
    code: 'id', mlKitCode: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia',
    flag: '🇮🇩', offlineSupported: true, ocrScript: TextScript.latin,
  ),
];

AppLanguage? findByCode(String code) {
  try {
    return kLanguages.firstWhere((l) => l.code == code);
  } catch (_) {
    return null;
  }
}
