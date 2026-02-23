import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/login_screen.dart';
import 'screens/display_selection_screen.dart';
import 'screens/order_status_screen.dart';
import 'screens/initial_setup_screen.dart';
import 'services/api_client_service.dart';
import 'services/settings_service.dart';
import 'services/audio_service.dart';
import 'services/device_control_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide Android navigation bar and status bar for immersive mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('OSD: .env file loaded successfully');

    // Debug: Output important environment variables
    debugPrint('OSD: FLUTTER_ENV = ${dotenv.env['FLUTTER_ENV']}');
    debugPrint('OSD: API_BASE_URL = ${dotenv.env['API_BASE_URL']}');
    debugPrint('OSD: WEBSOCKET_DEV_URL = ${dotenv.env['WEBSOCKET_DEV_URL']}');
    debugPrint(
        'OSD: WEBSOCKET_PRODUCTION_URL = ${dotenv.env['WEBSOCKET_PRODUCTION_URL']}');
    debugPrint('OSD: PLATFORM_MODE = ${dotenv.env['PLATFORM_MODE'] ?? 'standard'}');
  } catch (e) {
    debugPrint('OSD: .env file not found or failed to load: $e');
    debugPrint('OSD: Continuing with default environment variables');
  }

  // Initialize window manager for kiosk mode on desktop platforms
  await _initializeWindowManager();

  // Initialize services in order
  await SettingsService.initialize();

  // Initialize other services
  await AudioService.instance.initialize();
  await DeviceControlService.instance.initialize();

  runApp(const OSDApp());
}

/// Initialize window manager for kiosk mode on desktop platforms
Future<void> _initializeWindowManager() async {
  // Only apply to desktop platforms
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return;
  }

  // Check if kiosk mode is enabled
  final platformMode = dotenv.env['PLATFORM_MODE'] ?? 'standard';
  if (platformMode != 'kiosk') {
    debugPrint('OSD: Standard mode - skipping window manager initialization');
    return;
  }

  // Get kiosk settings
  final fullscreen = dotenv.env['KIOSK_FULLSCREEN'] == 'true';
  final alwaysOnTop = dotenv.env['KIOSK_ALWAYS_ON_TOP'] == 'true';
  final skipTaskbar = dotenv.env['KIOSK_SKIP_TASKBAR'] == 'true';

  if (!fullscreen && !alwaysOnTop) {
    return;
  }

  debugPrint('OSD: Kiosk mode - initializing window manager');
  debugPrint('OSD: Fullscreen=$fullscreen, AlwaysOnTop=$alwaysOnTop, SkipTaskbar=$skipTaskbar');

  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    title: 'Order Status Display',
    fullScreen: fullscreen,
    alwaysOnTop: alwaysOnTop,
    skipTaskbar: skipTaskbar,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (fullscreen) {
      await windowManager.setFullScreen(true);
    }
    if (alwaysOnTop) {
      await windowManager.setAlwaysOnTop(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });

  debugPrint('OSD: Window manager initialized successfully');
}

class OSDApp extends StatelessWidget {
  const OSDApp({super.key});

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A2E), // Dark navy
      cardColor: const Color(0xFF16213E),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1A1A2E),
        onSurface: Colors.white,
        primary: Color(0xFF0F3460), // Deep blue
        onPrimary: Colors.white,
        secondary: Color(0xFF00D9FF), // Cyan accent
        onSecondary: Colors.black,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF16213E),
        elevation: 4,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F3460),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D9FF),
          foregroundColor: Colors.black,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Light gray
      cardColor: Colors.white,
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFF5F5F5),
        onSurface: Color(0xFF1A1A2E),
        primary: Color(0xFF2196F3), // Blue
        onPrimary: Colors.white,
        secondary: Color(0xFF0288D1), // Light blue
        onSecondary: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService.instance),
        ChangeNotifierProvider(create: (_) => DeviceControlService.instance),
        ChangeNotifierProvider(create: (_) => AuthService.instance),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settingsService, child) {
          final isDarkMode = settingsService.isDarkMode;
          return MaterialApp(
            title: 'Order Status Display',
            theme: isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
            home: const InitialScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Use post frame callback to avoid calling Navigator during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('*** OSD MAIN: Initializing auth service...');

      final authService = AuthService.instance;
      await authService.initialize();

      if (!mounted) return;

      final authState = authService.currentState;
      debugPrint('*** OSD MAIN: Auth state: ${authState.status}');

      if (authState.isAuthenticated) {
        // User is authenticated, fetch displays
        debugPrint('*** OSD MAIN: User authenticated, fetching displays...');
        final displays = await authService.fetchOsdDisplays();

        if (!mounted) return;

        if (displays.isEmpty) {
          // No displays available, show login screen with error
          debugPrint('*** OSD MAIN: No displays available');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          // Try to auto-select a display
          final autoSelect = await authService.getAutoSelectDisplay(displays);

          if (autoSelect != null) {
            // Auto-select and go to main screen
            debugPrint('*** OSD MAIN: Auto-selecting display: ${autoSelect.name}');
            await authService.selectDisplay(autoSelect);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
            );
          } else {
            // Show selection screen
            debugPrint('*** OSD MAIN: Showing display selection screen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DisplaySelectionScreen()),
            );
          }
        }
      } else {
        // Not authenticated, check if this is first time setup needed
        final shouldShowSetup = await _shouldShowInitialSetup();

        if (!mounted) return;

        if (shouldShowSetup) {
          debugPrint('*** OSD MAIN: First time setup, showing Initial Setup Screen...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const InitialSetupScreen()),
          );
        } else {
          debugPrint('*** OSD MAIN: Not authenticated, navigating to Login Screen...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    });
  }

  /// Check if we should show the initial setup screen
  /// Returns true if:
  /// 1. Platform mode is 'kiosk'
  /// 2. No auto-login credentials are stored
  /// 3. No .env auto-login credentials are configured
  Future<bool> _shouldShowInitialSetup() async {
    // Check platform mode
    final platformMode = dotenv.env['PLATFORM_MODE'] ?? 'standard';
    if (platformMode != 'kiosk') {
      debugPrint('*** OSD MAIN: Standard mode, skipping initial setup');
      return false;
    }

    // Check if .env has auto-login credentials
    final envEmail = dotenv.env['AUTO_LOGIN_EMAIL'] ?? '';
    final envPassword = dotenv.env['AUTO_LOGIN_PASSWORD'] ?? '';
    if (envEmail.isNotEmpty && envPassword.isNotEmpty) {
      debugPrint('*** OSD MAIN: .env has auto-login credentials, skipping initial setup');
      return false;
    }

    // Check if stored credentials exist
    final apiClient = ApiClientService.instance;
    final isAutoLoginEnabled = await apiClient.isAutoLoginEnabled();
    final storedEmail = await apiClient.getStoredEmail();
    final storedPassword = await apiClient.getStoredPassword();

    if (isAutoLoginEnabled && storedEmail != null && storedPassword != null) {
      debugPrint('*** OSD MAIN: Stored credentials exist, skipping initial setup');
      return false;
    }

    // Kiosk mode with no credentials configured - show setup
    debugPrint('*** OSD MAIN: Kiosk mode with no credentials, showing initial setup');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            Image.asset(
              'assets/icons/app_icon.png',
              width: 120,
              height: 120,
            ),

            const SizedBox(height: 32),

            // App Name
            const Text(
              'Sciometa OSD',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Order Status Display',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 48),

            // Loading indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF2196F3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
