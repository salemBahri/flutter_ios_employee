class AppConstants {
  AppConstants._();

  // ==================== Font Configuration ====================

  /// الخط الافتراضي للتطبيق
  static const String defaultFont = 'Cairo';

  // ==================== API Configuration ====================

  static const String baseUrl = 'http://51.83.10.151:8069/jsonrpc';
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
  // ⭐ Base URL للصور (بدون /jsonrpc)
  static const String odooBaseUrl = 'http://51.83.10.151:8069';

  // ==================== Assets ====================

  static const String companyLogo = 'assets/images/company_logo.png';

  // ==================== SharedPreferences Keys ====================

  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';
  static const String keyPassword = 'user_password';
  static const String keyDatabase = 'database';
  static const String keySessionId = 'session_id';
  static const String keyLanguage = 'language';
  static const String keyRememberMe = 'remember_me';
  static const String keySavedUsername = 'saved_username';
  static const String keySavedPassword = 'saved_password';
  static const String keySavedDatabase = 'saved_database';
  static const String keyEmployeeId = 'employee_id';
  static const String keyEmployeeName = 'employee_name';
  static const String keyDepartmentId = 'department_id';
  static const String keyDepartmentName = 'department_name';

  // ==================== Language Codes ====================

  static const String languageFrench = 'fr';
  static const String languageArabic = 'ar';

  // ==================== JSON-RPC Configuration ====================

  static const String jsonRpcVersion = '2.0';
  static const String serviceDb = 'db';
  static const String serviceCommon = 'common';
  static const String serviceObject = 'object';
  static const String methodCall = 'call';
  static const String methodList = 'list';
  static const String methodAuthenticate = 'authenticate';
  static const String methodExecuteKw = 'execute_kw';
  static const String methodSearchRead = 'search_read';

  // ==================== Odoo Models ====================

  static const String modelHrEmployee = 'hr.employee';
  static const String modelMrpWorkorder = 'mrp.workorder';
  static const String modelResUsers = 'res.users';

  // ==================== HTTP Headers ====================

  static const String contentTypeJson = 'application/json';
  static const String headerContentType = 'Content-Type';
  static const String headerCookie = 'Cookie';
  static const String headerSetCookie = 'set-cookie';

  // ==================== App Configuration ====================

  static const String appNameFr = 'Centrale Meuble';
  static const String appNameAr = 'سنترال موبل';
  static const String appVersion = '1.0.9';

  // ==================== UI Constants ====================

  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultButtonHeight = 56.0;
  static const double defaultIconSize = 24.0;
  static const double largeIconSize = 48.0;
}
