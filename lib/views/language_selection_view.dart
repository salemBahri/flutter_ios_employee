import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/language_controller.dart';
import '../utils/app_localizations.dart';
import '../utils/constants.dart';
import 'login_view.dart';

class LanguageSelectionView extends StatefulWidget {
  const LanguageSelectionView({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionView> createState() => _LanguageSelectionViewState();
}

class _LanguageSelectionViewState extends State<LanguageSelectionView> {
  String? _selectedLanguage;

  @override
  Widget build(BuildContext context) {
    final languageController = Provider.of<LanguageController>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo sans cercle
                Image.asset(
                  AppConstants.companyLogo,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.business,
                      size: 120,
                      color: Color(0xFF3F51B5),
                    );
                  },
                )
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut)
                    .then()
                    .shimmer(duration: 1500.ms, color: const Color(0xFF3F51B5).withOpacity(0.2)),

                const SizedBox(height: 60),

                // Titre
                Text(
                  AppLocalizations(languageController.locale).translate('select_language'),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9900),
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: -0.3),

                const SizedBox(height: 16),

                // Sous-titre
                Text(
                  'Choose your preferred language',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                const SizedBox(height: 48),

                // Option Français
                _buildLanguageOption(
                  controller: languageController,
                  languageCode: 'fr',
                  languageName: 'Français',
                  flag: '🇫🇷',
                  color: const Color(0xFF3F51B5),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideX(begin: -0.2),

                const SizedBox(height: 16),

                // Option العربية
                _buildLanguageOption(
                  controller: languageController,
                  languageCode: 'ar',
                  languageName: 'العربية',
                  flag: '🇹🇳',
                  color: const Color(0xFF5C6BC0),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideX(begin: 0.2),

                const SizedBox(height: 32),

                // Bouton Continue
                if (_selectedLanguage != null)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await languageController.changeLanguage(_selectedLanguage!);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LoginView(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F51B5),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF3F51B5).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations(languageController.locale).translate('continue'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 24),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 40),

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
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required LanguageController controller,
    required String languageCode,
    required String languageName,
    required String flag,
    required Color color,
  }) {
    final isSelected = _selectedLanguage == languageCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLanguage = languageCode;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ]
                : [],
          ),
          child: Row(
            children: [
              // Flag emoji
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 20),

              // Language name
              Expanded(
                child: Text(
                  languageName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? color : Colors.grey[800],
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Checkmark ou Circle
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(8),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
