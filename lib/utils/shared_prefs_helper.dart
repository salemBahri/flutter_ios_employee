import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SharedPrefsHelper {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // حفظ بيانات المستخدم
  static Future<void> saveUserData({
    required int userId,
    required String username,
    required String database,
    required String sessionId,
    String? password, // ⭐ أضف هذا السطر
    int? employeeId,
    String? employeeName,
    int? departmentId,
    String? departmentName,
  }) async {
    await _prefs?.setInt(AppConstants.keyUserId, userId);
    await _prefs?.setString(AppConstants.keyUsername, username);
    await _prefs?.setString(AppConstants.keyDatabase, database);
    await _prefs?.setString(AppConstants.keySessionId, sessionId);

    // ⭐ حفظ كلمة المرور
    if (password != null) {
      await _prefs?.setString(AppConstants.keyPassword, password);
    }

    if (employeeId != null) {
      await _prefs?.setInt(AppConstants.keyEmployeeId, employeeId);
    }
    if (employeeName != null) {
      await _prefs?.setString(AppConstants.keyEmployeeName, employeeName);
    }
    if (departmentId != null) {
      await _prefs?.setInt(AppConstants.keyDepartmentId, departmentId);
    }
    if (departmentName != null) {
      await _prefs?.setString(AppConstants.keyDepartmentName, departmentName);
    }
  }

  // حفظ بيانات تذكرني
  static Future<void> saveRememberMe({
    required bool rememberMe,
    String? username,
    String? password,
    String? database,
  }) async {
    await _prefs?.setBool(AppConstants.keyRememberMe, rememberMe);
    if (rememberMe && username != null && password != null && database != null) {
      await _prefs?.setString(AppConstants.keySavedUsername, username);
      await _prefs?.setString(AppConstants.keySavedPassword, password);
      await _prefs?.setString(AppConstants.keySavedDatabase, database);
    } else {
      await _prefs?.remove(AppConstants.keySavedUsername);
      await _prefs?.remove(AppConstants.keySavedPassword);
      await _prefs?.remove(AppConstants.keySavedDatabase);
    }
  }

  // جلب بيانات تذكرني
  static Map<String, String?> getRememberMeData() {
    return {
      'username': _prefs?.getString(AppConstants.keySavedUsername),
      'password': _prefs?.getString(AppConstants.keySavedPassword),
      'database': _prefs?.getString(AppConstants.keySavedDatabase),
    };
  }

  static bool getRememberMe() {
    return _prefs?.getBool(AppConstants.keyRememberMe) ?? false;
  }

  // التحقق من تسجيل الدخول
  static bool isLoggedIn() {
    return _prefs?.getInt(AppConstants.keyUserId) != null;
  }

  // حفظ اللغة
  static Future<void> saveLanguage(String languageCode) async {
    await _prefs?.setString(AppConstants.keyLanguage, languageCode);
  }

  static String? getLanguage() {
    return _prefs?.getString(AppConstants.keyLanguage);
  }

  // ⭐ الحصول على كلمة المرور
  static String? getPassword() {
    return _prefs?.getString(AppConstants.keyPassword);
  }

  // الحصول على بيانات المستخدم
  static Map<String, dynamic>? getUserData() {
    final userId = _prefs?.getInt(AppConstants.keyUserId);
    if (userId == null) return null;

    return {
      'userId': userId,
      'username': _prefs?.getString(AppConstants.keyUsername),
      'database': _prefs?.getString(AppConstants.keyDatabase),
      'sessionId': _prefs?.getString(AppConstants.keySessionId),
      'password': _prefs?.getString(AppConstants.keyPassword), // ⭐ أضف هذا
      'employeeId': _prefs?.getInt(AppConstants.keyEmployeeId),
      'employeeName': _prefs?.getString(AppConstants.keyEmployeeName),
    };
  }

  // الحصول على بيانات القسم
  static Map<String, dynamic>? getDepartmentData() {
    final deptId = _prefs?.getInt(AppConstants.keyDepartmentId);
    final deptName = _prefs?.getString(AppConstants.keyDepartmentName);

    if (deptId == null && deptName == null) return null;

    return {
      'departmentId': deptId,
      'departmentName': deptName,
    };
  }

  // تسجيل الخروج
  static Future<void> logout() async {
    await _prefs?.remove(AppConstants.keyUserId);
    await _prefs?.remove(AppConstants.keyUsername);
    await _prefs?.remove(AppConstants.keyDatabase);
    await _prefs?.remove(AppConstants.keySessionId);
    await _prefs?.remove(AppConstants.keyPassword); // ⭐ أضف هذا
    await _prefs?.remove(AppConstants.keyEmployeeId);
    await _prefs?.remove(AppConstants.keyEmployeeName);
    await _prefs?.remove(AppConstants.keyDepartmentId);
    await _prefs?.remove(AppConstants.keyDepartmentName);
  }
}
