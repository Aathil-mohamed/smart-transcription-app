import 'package:flutter/material.dart';

class AppConstants {
  // Firestore Collection Names
  static const String collectionUsers = 'users';
  static const String collectionTranscriptions = 'transcriptions';
  static const String collectionExports = 'exports';

  // Supported Languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'bilingual', 'name': 'Bilingual (Tamil + English)'},
    {'code': 'ta-IN', 'name': 'Tamil (தமிழ்)'},
    {'code': 'en-US', 'name': 'English (United States)'},
  ];

  // API Configurations
  // NOTE: For final year IT project, we use Groq's free tier Whisper-large-v3 API
  // You can register for a free API key at https://console.groq.com/
  static const String groqApiKey = 'gsk_xxxxxx_PLACEHOLDER_KEY'; 
  static const String groqWhisperUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';

  // Shared Preferences keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyUserLanguage = 'user_language';

  // Design Tokens (Premium Palette)
  static const Color primaryDark = Color(0xFF6C63FF); // Deep Indigo
  static const Color accentDark = Color(0xFF00E6FF);  // Vibrant Cyan
  static const Color backgroundDark = Color(0xFF0F0E17); // Dark Rich Slate
  static const Color surfaceDark = Color(0xFF1E1C2A);   // Card Background
  static const Color textPrimaryDark = Color(0xFFFFFEFA);
  static const Color textSecondaryDark = Color(0xFFA7A6BA);

  static const Color primaryLight = Color(0xFF4F46E5); // Royal Purple
  static const Color accentLight = Color(0xFF0891B2);  // Rich Cyan
  static const Color backgroundLight = Color(0xFFF8FAFC); // Clean Slate Gray
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
}
