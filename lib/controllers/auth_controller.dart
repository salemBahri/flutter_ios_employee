import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../models/user_model.dart';
import '../models/employee_model.dart';
import '../utils/shared_prefs_helper.dart';

class AuthController extends ChangeNotifier {
  final OdooService _odooService = OdooService();

  UserModel? _currentUser;
  EmployeeModel? _currentEmployee;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  EmployeeModel? get currentEmployee => _currentEmployee;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> login({
    required String database,
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🔐 محاولة تسجيل الدخول...');

      // المصادقة
      final authResult = await _odooService.authenticate(
        database,
        username,
        password,
      );

      final userId = authResult['userId'];
      final sessionId = authResult['sessionId'];

      print('✅ تم تسجيل الدخول - معرف المستخدم: $userId');

      // التحقق من أن المستخدم موظف
      final employeeData = await _odooService.checkEmployee(
        database,
        userId,
        password,
      );

      if (employeeData == null) {
        _error = 'هذا المستخدم ليس موظفاً';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('✅ تم التحقق من الموظف - معرف الموظف: ${employeeData['id']}');

      // حفظ بيانات المستخدم
      _currentUser = UserModel(
        userId: userId,
        username: username,
        database: database,
        sessionId: sessionId,
      );

      // حفظ بيانات الموظف
      _currentEmployee = EmployeeModel.fromJson(employeeData);

      // حفظ جميع البيانات في SharedPreferences مع كلمة المرور
      await SharedPrefsHelper.saveUserData(
        userId: userId,
        username: username,
        database: database,
        sessionId: sessionId,
        password: password, // ⭐ أضف كلمة المرور هنا
        employeeId: _currentEmployee!.id,
        employeeName: _currentEmployee!.name,
        departmentId: _currentEmployee!.departmentId,
        departmentName: _currentEmployee!.departmentName,
      );

      print('✅ تم حفظ بيانات المستخدم بنجاح');

      // حفظ بيانات تذكرني
      await SharedPrefsHelper.saveRememberMe(
        rememberMe: rememberMe,
        username: rememberMe ? username : null,
        password: rememberMe ? password : null,
        database: rememberMe ? database : null,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await SharedPrefsHelper.logout();
    _currentUser = null;
    _currentEmployee = null;
    notifyListeners();
  }

  void loadUserFromPrefs() {
    final userData = SharedPrefsHelper.getUserData();
    if (userData != null) {
      _currentUser = UserModel(
        userId: userData['userId'],
        username: userData['username'],
        database: userData['database'],
        sessionId: userData['sessionId'],
      );

      // تحميل بيانات الموظف من SharedPreferences
      final employeeId = userData['employeeId'];
      final employeeName = userData['employeeName'];
      final departmentData = SharedPrefsHelper.getDepartmentData();

      if (employeeId != null && employeeName != null) {
        _currentEmployee = EmployeeModel(
          id: employeeId,
          name: employeeName,
          departmentId: departmentData?['departmentId'],
          departmentName: departmentData?['departmentName'],
        );
      }

      notifyListeners();
    }
  }
}
