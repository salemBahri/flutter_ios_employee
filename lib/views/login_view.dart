import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/auth_controller.dart';
import '../controllers/database_controller.dart';
import '../controllers/language_controller.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';
import '../utils/shared_prefs_helper.dart';
import 'my_workorder_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedDatabase;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final dbController = Provider.of<DatabaseController>(context, listen: false);
    await dbController.loadDatabases();

    if (SharedPrefsHelper.getRememberMe()) {
      final rememberData = SharedPrefsHelper.getRememberMeData();
      setState(() {
        _usernameController.text = rememberData['username'] ?? '';
        _passwordController.text = rememberData['password'] ?? '';
        _selectedDatabase = rememberData['database'];
        _rememberMe = true;
      });
    }

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDatabase == null) {
      _showError(AppLocalizations.of(context).translate('select_database'));
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);

    final success = await authController.login(
      database: _selectedDatabase!,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MyWorkorderView(),
        ),
      );
    } else if (authController.error != null && mounted) {
      _showError(authController.error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageController = Provider.of<LanguageController>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          localizations.translate('connection'),
          style: const TextStyle(
            color: Color(0xFFFF9900),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF455A64), size: 28),
            onPressed: () => _showLanguageDialog(context, languageController),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final dbController = Provider.of<DatabaseController>(context, listen: false);
          await dbController.loadDatabases();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _isInitialized
                ? _buildLoginForm(context, localizations)
                : const Center(
              child: CircularProgressIndicator(color: Color(0xFF455A64)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, AppLocalizations localizations) {
    final authController = Provider.of<AuthController>(context);
    final dbController = Provider.of<DatabaseController>(context);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Logo sans cercle
          Image.asset(
            AppConstants.companyLogo,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.business,
                size: 120,
                color: Color(0xFF455A64),
              );
            },
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 48),

          // Database Dropdown
          DropdownButtonFormField<String>(
            value: _selectedDatabase,
            decoration: InputDecoration(
              labelText: localizations.translate('database'),
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: const Icon(Icons.storage, color: Color(0xFF455A64)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF455A64), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            items: dbController.databases
                .map((db) => DropdownMenuItem(
              value: db.name,
              child: Text(db.name),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedDatabase = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations.translate('select_database');
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2),

          const SizedBox(height: 20),

          // Username
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: localizations.translate('username'),
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF455A64)),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF455A64), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations.translate('username');
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2),

          const SizedBox(height: 20),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: localizations.translate('password'),
              labelStyle: TextStyle(color: Colors.grey[700]),
              prefixIcon: const Icon(Icons.lock, color: Color(0xFF455A64)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF455A64), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localizations.translate('password');
              }
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2),

          const SizedBox(height: 16),

          // Remember Me
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: const Color(0xFF455A64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                localizations.translate('remember_me'),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 15,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

          const SizedBox(height: 32),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: authController.isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF455A64).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: authController.isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : Text(
                localizations.translate('login'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideY(begin: 0.3),
          SizedBox(height: 40),
          // Version
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version ${AppConstants.appVersion}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LanguageController controller) {
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 5,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec icône
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF455A64).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.language,
                  color: Color(0xFF455A64),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),

              // Titre
              Text(
                localizations.translate('change_language'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9900),
                ),
              ),
              const SizedBox(height: 24),

              // Option Français
              _buildLanguageOption(
                context: dialogContext,
                controller: controller,
                languageCode: 'fr',
                languageName: 'Français',
                flag: '🇫🇷',
                color: const Color(0xFF455A64),
              ),

              const SizedBox(height: 12),

              // Option العربية
              _buildLanguageOption(
                context: dialogContext,
                controller: controller,
                languageCode: 'ar',
                languageName: 'العربية',
                flag: '🇹🇳',
                color: const Color(0xFF5C6BC0),
              ),

              const SizedBox(height: 20),

              // Bouton Fermer
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  localizations.translate('cancel'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required LanguageController controller,
    required String languageCode,
    required String languageName,
    required String flag,
    required Color color,
  }) {
    final isSelected = controller.locale.languageCode == languageCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await controller.changeLanguage(languageCode);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Flag emoji
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 16),

              // Language name
              Expanded(
                child: Text(
                  languageName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[800],
                  ),
                ),
              ),

              // Checkmark
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLanguageTile(String title, String code, LanguageController controller, BuildContext dialogContext) {
    final isSelected = controller.locale.languageCode == code;

    return InkWell(
      onTap: () async {
        await controller.changeLanguage(code);
        Navigator.pop(dialogContext);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF455A64).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF455A64) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: code,
              groupValue: controller.locale.languageCode,
              onChanged: (value) async {
                await controller.changeLanguage(value!);
                Navigator.pop(dialogContext);
              },
              activeColor: const Color(0xFF455A64),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF455A64) : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
