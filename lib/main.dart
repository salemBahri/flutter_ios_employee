import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/database_controller.dart';
import 'controllers/language_controller.dart';
import 'controllers/workorders_controller.dart';
import 'utils/app_localizations.dart';
import 'utils/shared_prefs_helper.dart';
import 'views/language_selection_view.dart';
import 'views/login_view.dart';
import 'views/my_workorder_view.dart';
import 'views/notifications_history_view.dart';
import 'services/notification_service.dart';

// ⭐ مفتاح Navigator عام - يسمح لـ NotificationService بالتنقل عند الضغط على إشعار
// بدون الحاجة لـ BuildContext مباشر (يشتغل حتى لو كان التطبيق مغلقاً تماماً)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefsHelper.init();

  // ⭐ ربط الـ navigatorKey بالخدمة قبل التهيئة
  NotificationService.navigatorKey = navigatorKey;
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => DatabaseController()),
        ChangeNotifierProvider(create: (_) => WorkOrdersController()),
      ],
      child: Consumer<LanguageController>(
        builder: (context, languageController, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final workordersController =
            Provider.of<WorkOrdersController>(context, listen: false);
            workordersController.updateLanguage(languageController.locale.languageCode);

            // ⭐ إذا فُتح التطبيق أصلاً عبر الضغط على إشعار (cold start)، ننقل المستخدم الآن
            // بعد أول frame، حيث يكون الـ Navigator جاهزاً فعلياً
            NotificationService().checkPendingNavigation();
          });

          return MaterialApp(
            navigatorKey: navigatorKey, // ⭐ ربط الـ key بالتطبيق
            title: 'Centrale Meuble',
            debugShowCheckedModeBanner: false,
            locale: languageController.locale,
            supportedLocales: const [
              Locale('fr'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              fontFamily: 'Cairo',
            ),

            // ⭐ تسجيل route شاشة سجل الإشعارات حتى تقدر NotificationService تفتحها بالاسم
            routes: {
              NotificationService.notificationsRouteName: (context) =>
              const NotificationsHistoryView(),
            },

            home: _getInitialScreen(languageController),
          );
        },
      ),
    );
  }

  Widget _getInitialScreen(LanguageController languageController) {
    if (SharedPrefsHelper.isLoggedIn()) {
      return const MyWorkorderView();
    }

    if (!languageController.isLanguageSelected()) {
      return const LanguageSelectionView();
    }

    return const LoginView();
  }
}
