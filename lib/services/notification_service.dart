import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ⭐ خدمة الإشعارات المحلية - Singleton
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool? _permissionGranted;
  bool _launchedFromNotification = false;

  static const String channelId = 'workorder_channel';
  static const String channelName = 'Work Orders';
  static const String channelDescription = 'إشعارات أوامر العمل';

  static const String soundResourceName = 'notification_sound';

  static const Color accentColor = Color(0xFFD32F2F);

  /// ⭐ يُضبط من main.dart - يسمح للخدمة بالتنقل بدون الحاجة لـ BuildContext مباشر
  static GlobalKey<NavigatorState>? navigatorKey;

  /// ⭐ اسم الـ route المسجّل في MaterialApp لشاشة سجل الإشعارات
  static const String notificationsRouteName = '/notifications';

  bool? get permissionGranted => _permissionGranted;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    final initResult = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        print('🔔 [NOTIF] تم الضغط على إشعار - payload: ${response.payload}');
        _navigateToNotifications();
      },
    );

    print('🔔 [NOTIF] نتيجة تهيئة الـ plugin: $initResult');

    // ⭐ التحقق إذا تم فتح التطبيق أصلاً عن طريق الضغط على إشعار (والتطبيق كان مغلقاً تماماً)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      print('🔔 [NOTIF] 🚀 تم فتح التطبيق عبر الضغط على إشعار (cold start)');
      _launchedFromNotification = true;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      print('🔔 [NOTIF] ⚠️ androidPlugin هو null');
    }

    try {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundResourceName),
      );
      await androidPlugin?.createNotificationChannel(androidChannel);
      print('🔔 [NOTIF] تم إنشاء القناة بالصوت المخصص: $channelId');
    } catch (e) {
      print('🔔 [NOTIF] ⚠️ فشل إنشاء القناة بالصوت المخصص ($e) - سيتم استخدام الصوت الافتراضي');
      const fallbackChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
      );
      await androidPlugin?.createNotificationChannel(fallbackChannel);
    }

    _permissionGranted = await androidPlugin?.requestNotificationsPermission();
    print('🔔 [NOTIF] نتيجة طلب صلاحية الإشعارات: $_permissionGranted');

    final areEnabled = await androidPlugin?.areNotificationsEnabled();
    print('🔔 [NOTIF] areNotificationsEnabled = $areEnabled');

    _initialized = true;
  }

  /// ⭐ يُستدعى من main.dart بعد أول frame - ينقل المستخدم لشاشة السجل
  /// إذا كان التطبيق قد فُتح أصلاً عبر الضغط على إشعار (cold start)
  void checkPendingNavigation() {
    if (_launchedFromNotification) {
      _launchedFromNotification = false;
      print('🔔 [NOTIF] 🚀 تنفيذ التنقل المؤجل بعد cold start');
      _navigateToNotifications();
    }
  }

  void _navigateToNotifications() {
    final state = navigatorKey?.currentState;
    if (state == null) {
      print('🔔 [NOTIF] ⚠️ navigatorKey غير جاهز بعد - لا يمكن التنقل الآن');
      return;
    }
    state.pushNamed(notificationsRouteName);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isHtml = true,
  }) async {
    if (!_initialized) await init();

    final styleInfo = isHtml
        ? const DefaultStyleInformation(true, true)
        : const DefaultStyleInformation(false, false);

    final bigTextStyle = isHtml
        ? BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    )
        : null;

    final androidDetailsCustomSound = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(soundResourceName),
      icon: '@mipmap/ic_launcher',
      color: accentColor,
      styleInformation: bigTextStyle ?? styleInfo,
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetailsCustomSound),
        payload: payload,
      );
      print('🔔 [NOTIF] ✅ show() نُفذ بنجاح بالصوت المخصص (id=$id)');
      return;
    } catch (e) {
      print('🔔 [NOTIF] ⚠️ فشل show() بالصوت المخصص: $e');
      print('🔔 [NOTIF] ⚠️ تأكد أن الملف موجود في: android/app/src/main/res/raw/$soundResourceName.mp3');
      print('🔔 [NOTIF] ⏭️ إعادة المحاولة بالصوت الافتراضي...');
    }

    final androidDetailsDefaultSound = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: accentColor,
      styleInformation: bigTextStyle ?? styleInfo,
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetailsDefaultSound),
        payload: payload,
      );
      print('🔔 [NOTIF] ✅ show() نُفذ بنجاح بالصوت الافتراضي (id=$id)');
    } catch (e, st) {
      print('🔔 [NOTIF] ❌ فشل show() حتى بالصوت الافتراضي: $e');
      print('🔔 [NOTIF] Stack: $st');
    }
  }

  Future<void> showTestNotification() async {
    print('🔔 [NOTIF] ▶️ إرسال إشعار تجريبي يدوي...');
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final areEnabled = await androidPlugin?.areNotificationsEnabled();
    print('🔔 [NOTIF] حالة الصلاحية وقت الاختبار: areNotificationsEnabled = $areEnabled');

    await show(
      id: 999999,
      title: '<b><big>🔔 اختبار الإشعارات</big></b>',
      body: '<b><big>إذا شفت هذا 🔴 Bold 🔴، النظام يعمل تماماً</big></b>',
    );
  }
}
