import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/display_selection_screen.dart';
import 'screens/order_status_screen.dart';
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
  } catch (e) {
    debugPrint('OSD: .env file not found or failed to load: $e');
    debugPrint('OSD: Continuing with default environment variables');
  }

  // Initialize services in order
  await SettingsService.initialize();

  // Initialize other services
  await AudioService.instance.initialize();
  await DeviceControlService.instance.initialize();

  runApp(const OSDApp());
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
        } else if (displays.length == 1) {
          // Only one display, auto-select and go to main screen
          debugPrint(
              '*** OSD MAIN: Auto-selecting single display: ${displays.first.name}');
          await authService.selectDisplay(displays.first);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
          );
        } else {
          // Multiple displays, show selection screen
          debugPrint('*** OSD MAIN: Multiple displays, showing selection screen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DisplaySelectionScreen()),
          );
        }
      } else {
        // Not authenticated, show login screen
        debugPrint(
            '*** OSD MAIN: Not authenticated, navigating to Login Screen...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F3460),
                    Color(0xFF00D9FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.monitor,
                size: 80,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 32),

            // App Name
            const Text(
              'Sciometa OSD',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Order Status Display',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF9CA3AF),
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
                  Color(0xFF00D9FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
