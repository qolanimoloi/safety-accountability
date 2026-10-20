import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/fallback_localizations.dart';
import 'app_nav.dart';
import 'widgets/custom_bottom_nav.dart';
import 'widgets/header.dart';
import 'screens/location_page.dart';
import 'screens/emergency_page.dart';
import 'screens/community_page.dart';
import 'screens/ehailing_page.dart';
import 'screens/auth_page.dart';
import 'app_settings.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedSettings();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await AuthService.tryAutoLogin();
    if (!mounted) return;
    isLoggedIn.value = loggedIn;
    setState(() {
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, language, _) {
            return MaterialApp(
              title: 'Safety & Accountability',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              locale: localeForLanguage(language),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                FallbackMaterialLocalizationsDelegate(),
                GlobalWidgetsLocalizations.delegate,
                FallbackCupertinoLocalizationsDelegate(),
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                brightness: Brightness.light,
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007BFF)),
                scaffoldBackgroundColor: const Color(0xFFF7F8FA),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF007BFF),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
              ),
              home: _checkingSession
                  ? const _SplashScreen()
                  : ValueListenableBuilder<bool>(
                      valueListenable: isLoggedIn,
                      builder: (context, loggedIn, _) {
                        return loggedIn ? const HomeScreen() : const AuthPage();
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    // Always white, to match the native splash screen.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/images/logo.png'),
              width: 240,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF007BFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // A tab is only built the first time it is opened, then kept alive.
  final List<bool> _visited = [true, false, false, false];

  @override
  void initState() {
    super.initState();
    AppNav.tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    AppNav.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  // A notification (or another screen) asked to show a tab.
  void _onTabRequest() {
    final index = AppNav.tabRequest.value;
    if (index == null) return;
    AppNav.tabRequest.value = null;
    if (index >= 0 && index < 4) _onNavTap(index);
  }

  Widget _pageFor(int index) {
    switch (index) {
      case 0:
        return const LocationPage();
      case 1:
        return const EmergencyPage();
      case 2:
        return const EhailingPage();
      default:
        return const CommunityPage();
    }
  }

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
      _visited[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: List.generate(
                  4,
                  (i) => _visited[i] ? _pageFor(i) : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}