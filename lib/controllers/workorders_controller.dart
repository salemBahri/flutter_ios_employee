import 'dart:async';
import 'package:flutter/material.dart';
import '../models/workorder_model.dart';
import '../services/odoo_service.dart';
import '../services/notification_service.dart';
import '../services/notification_db_helper.dart';
import '../utils/shared_prefs_helper.dart';
import '../utils/app_localizations.dart';

class WorkOrdersController extends ChangeNotifier {
  final OdooService _odooService = OdooService();
  final NotificationService _notificationService = NotificationService();
  final NotificationDbHelper _notificationDb = NotificationDbHelper();

  List<WorkOrderModel> _allWorkOrders = [];
  List<WorkOrderModel> _filteredWorkOrders = [];
  bool _isLoading = false;
  String? _error;
  bool _urgentFilterActive = false;

  Timer? _pollTimer;
  Set<int> _knownWorkOrderIds = {};
  String _currentLangCode = 'fr';
  int _pollCount = 0;
  bool _isPolling = false;

  List<WorkOrderModel> get workOrders => _filteredWorkOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get urgentFilterActive => _urgentFilterActive;

  Future<void> loadWorkOrders() async {
    _isLoading = true;
    _error = null;
    _urgentFilterActive = false;
    notifyListeners();

    try {
      final userData = SharedPrefsHelper.getUserData();

      print('📊 بيانات المستخدم الكاملة: $userData');

      if (userData == null) {
        throw Exception('لا توجد بيانات مستخدم');
      }

      final employeeId = userData['employeeId'];
      final database = userData['database'];
      final userId = userData['userId'];
      final password = userData['password'];

      if (employeeId == null) {
        throw Exception('معرف الموظف غير موجود');
      }

      if (database == null || userId == null) {
        throw Exception('بيانات الجلسة غير موجودة');
      }

      if (password == null || password.isEmpty) {
        throw Exception('⚠️ كلمة المرور غير موجودة. يرجى تسجيل الدخول مرة أخرى');
      }

      print('📋 جلب Work Orders...');

      final allOrders = await _odooService.fetchWorkOrders(
        database: database,
        userId: userId,
        password: password,
        employeeId: employeeId,
        urgentOnly: false,
      );

      print('✅ تم جلب ${allOrders.length} أمر عمل');

      _allWorkOrders = allOrders
          .map((json) => WorkOrderModel.fromJson(json, isUrgent: false))
          .toList();

      _filteredWorkOrders = _allWorkOrders;

      _knownWorkOrderIds = _allWorkOrders.map((w) => w.id).toSet();
      _pollCount = 0;

      print('🔔 [NOTIF] تم تسجيل ${_knownWorkOrderIds.length} أمر عمل كـ "معروف" عند التحميل: $_knownWorkOrderIds');
      print('✅ إجمالي أوامر العمل: ${_allWorkOrders.length}');

      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ خطأ في loadWorkOrders: $e');
      print('❌ Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleUrgentFilter() async {
    _urgentFilterActive = !_urgentFilterActive;

    if (_urgentFilterActive) {
      await _loadUrgentWorkOrders();
    } else {
      _filteredWorkOrders = _allWorkOrders;
      notifyListeners();
    }
  }

  Future<void> _loadUrgentWorkOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userData = SharedPrefsHelper.getUserData();

      if (userData == null) {
        throw Exception('لا توجد بيانات مستخدم');
      }

      final employeeId = userData['employeeId'];
      final database = userData['database'];
      final userId = userData['userId'];
      final password = userData['password'];

      if (employeeId == null || database == null || userId == null || password == null) {
        throw Exception('بيانات غير مكتملة');
      }

      print('🚨 جلب Work Orders العاجلة فقط...');

      final urgentOrders = await _odooService.fetchWorkOrders(
        database: database,
        userId: userId,
        password: password,
        employeeId: employeeId,
        urgentOnly: true,
      );

      print('✅ تم جلب ${urgentOrders.length} أمر عمل عاجل');

      _filteredWorkOrders = urgentOrders
          .map((json) => WorkOrderModel.fromJson(json, isUrgent: true))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ خطأ في _loadUrgentWorkOrders: $e');
      _error = e.toString();
      _isLoading = false;
      _urgentFilterActive = false;
      notifyListeners();
    }
  }

  List<WorkOrderModel> getWorkOrdersByStatus(WorkOrderStatus status) {
    return _filteredWorkOrders
        .where((wo) => wo.customStatus == status)
        .toList();
  }

  // ==================== ⭐ نظام الإشعارات المحلية ====================

  void startPolling({required String langCode}) {
    _currentLangCode = langCode;
    _pollTimer?.cancel();
    print('🔔 [NOTIF] تم بدء الـ polling كل 10 ثواني - اللغة: $langCode');
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollForChanges());
  }

  void updateLanguage(String langCode) {
    _currentLangCode = langCode;
    print('🔔 [NOTIF] تم تحديث لغة الإشعارات إلى: $langCode');
  }

  void stopPolling() {
    print('🔔 [NOTIF] تم إيقاف الـ polling');
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollForChanges() async {
    if (_isPolling) {
      print('🔔 [NOTIF] ⏭️ دورة سابقة لم تنتهِ بعد - تم تخطي هذه الدورة');
      return;
    }
    _isPolling = true;
    _pollCount++;
    print('🔔 [NOTIF] ===== دورة Polling رقم $_pollCount =====');

    try {
      final userData = SharedPrefsHelper.getUserData();
      if (userData == null) {
        print('🔔 [NOTIF] ⚠️ لا توجد بيانات مستخدم - تم إيقاف الفحص');
        return;
      }

      final employeeId = userData['employeeId'];
      final database = userData['database'];
      final userId = userData['userId'];
      final password = userData['password'];
      final employeeName = userData['employeeName'] as String? ?? '';

      if (employeeId == null || database == null || userId == null || password == null) {
        print('🔔 [NOTIF] ⚠️ بيانات غير مكتملة - تم إيقاف الفحص');
        return;
      }

      final rawOrders = await _odooService.fetchWorkOrders(
        database: database,
        userId: userId,
        password: password,
        employeeId: employeeId,
        urgentOnly: false,
      );

      final orders = rawOrders.map((j) => WorkOrderModel.fromJson(j)).toList();
      final currentIds = orders.map((w) => w.id).toSet();

      print('🔔 [NOTIF] عدد أوامر العمل المجلوبة الآن: ${orders.length} -> IDs: $currentIds');
      print('🔔 [NOTIF] أوامر العمل المعروفة مسبقاً: $_knownWorkOrderIds');

      final newIds = currentIds.difference(_knownWorkOrderIds);

      if (newIds.isNotEmpty) {
        print('🔔 [NOTIF] 🆕 تم اكتشاف ${newIds.length} أمر عمل جديد: $newIds');
        for (final wo in orders.where((w) => newIds.contains(w.id))) {
          await _notifyNewWorkOrder(wo, userId as int, employeeName);
        }
      } else {
        print('🔔 [NOTIF] لا يوجد أمر عمل جديد في هذه الدورة');
      }

      _knownWorkOrderIds = currentIds;

      _allWorkOrders = orders;
      if (!_urgentFilterActive) {
        _filteredWorkOrders = orders;
      }
      notifyListeners();

      print('🔔 [NOTIF] ===== نهاية دورة Polling رقم $_pollCount =====');
    } catch (e, st) {
      print('⚠️ [NOTIF] خطأ أثناء polling الإشعارات: $e');
      print('⚠️ [NOTIF] Stack trace: $st');
    } finally {
      _isPolling = false;
    }
  }

  String _cleanProductName(String? productName) {
    if (productName == null || productName.isEmpty) return '';
    final cleanName = productName.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
    return cleanName.trim();
  }

  /// ⭐ نص الإشعار للـ System Tray: Bold + أكبر فقط (Android يتجاهل الألوان هناك)
  String _buildHighlightedMessage(String template, {
    required String name,
    required String product,
  }) {
    var message = template
        .replaceAll('{name}', '<b>$name</b>')
        .replaceAll('{product}', '<b>$product</b>')
        .replaceAll('\n', '<br>');

    return '<b><big>$message</big></b>';
  }

  Future<void> _notifyNewWorkOrder(WorkOrderModel wo, int userId, String employeeName) async {
    print('🔔 [NOTIF] >> محاولة إرسال إشعار "أمر جديد" للـ workorder ${wo.id} - المستخدم $userId');

    final alreadyNotified = await _notificationDb.hasNotified(
      userId: userId,
      workorderId: wo.id,
      type: 'new_workorder',
    );

    if (alreadyNotified) {
      print('🔔 [NOTIF] ⛔ تم تجاهل الإشعار - سبق إرساله لهذا الـ workorder من قبل (موجود في SQLite)');
      return;
    }

    final title = AppLocalizations.translateFor(_currentLangCode, 'notif_new_workorder_title');
    final cleanedProduct = _cleanProductName(wo.productName);
    final productDisplay = cleanedProduct.isNotEmpty ? cleanedProduct : wo.name;

    final template = AppLocalizations.translateFor(_currentLangCode, 'notif_new_workorder_message');

    // ⭐ نسخة System Tray (Bold فقط)
    final trayBody = _buildHighlightedMessage(
      template,
      name: employeeName,
      product: productDisplay,
    );

    // ⭐ نسخة عادية (بدون HTML) لحفظها في سجل الإشعارات - ستُلوَّن لاحقاً بـ RichText في الشاشة
    final plainBody = template
        .replaceAll('{name}', employeeName)
        .replaceAll('{product}', productDisplay);

    print('🔔 [NOTIF] 📤 استدعاء NotificationService.show() -> title="$title" body="$trayBody"');

    await _notificationService.show(
      id: wo.id * 10 + 1,
      title: title,
      body: trayBody,
      payload: 'workorder_${wo.id}',
      isHtml: true,
    );

    // ⭐ حفظ highlight1/highlight2 حتى تقدر شاشة السجل تلوّن الاسم والمنتج فعلياً
    await _notificationDb.insertNotification(
      userId: userId,
      workorderId: wo.id,
      type: 'new_workorder',
      title: title,
      body: plainBody,
      language: _currentLangCode,
      highlight1: employeeName,
      highlight2: productDisplay,
    );

    print('🔔 [NOTIF] 💾 تم حفظ الإشعار في SQLite');
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
