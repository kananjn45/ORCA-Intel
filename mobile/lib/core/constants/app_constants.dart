class AppConstants {
  static const String appName = 'ORCA Marine AI';
  static const String problemStatementId = '26176';
  static const String appVersion = '1.0.0';

  // Supported Regional Indian Languages (Bhashini Pipeline)
  static const Map<String, String> supportedLanguages = {
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'hi': 'हिन्दी (Hindi)',
    'bn': 'বাংলা (Bengali)',
    'gu': 'ગુજરાતી (Gujarati)',
    'en': 'English',
  };

  // Deterministic Safety Thresholds
  static const double maxSafeWaveHeightM = 2.5;
  static const double maxSafeWindSpeedKnots = 25.0;
  static const double imblCriticalDistanceKm = 2.0;
  static const double imblWarningDistanceKm = 5.0;
  static const double defaultLookaheadMinutes = 15.0;

  // Geographic Bounding Defaults (Palk Strait & Coromandel Coast)
  static const double defaultLatitude = 9.2854;
  static const double defaultLongitude = 79.3121;
  static const double defaultZoom = 10.5;

  // Local Storage Keys
  static const String offlinePackKey = 'orca_offline_pack_active';
  static const String selectedLanguageKey = 'orca_selected_lang';
  static const String sunlightModeKey = 'orca_sunlight_mode';
}
