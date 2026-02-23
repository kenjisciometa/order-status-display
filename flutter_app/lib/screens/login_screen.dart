import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import 'display_selection_screen.dart';
import 'order_status_screen.dart';

/// Login Screen
///
/// Allows users to authenticate with email and password or Google.
/// Two-column layout on wide screens (Email left, Google right).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// Check if auto-login is configured and perform auto-login
  Future<void> _checkAutoLogin() async {
    // Only auto-login in kiosk mode
    final platformMode = dotenv.env['PLATFORM_MODE'] ?? 'standard';
    if (platformMode != 'kiosk') {
      return;
    }

    final autoEmail = dotenv.env['AUTO_LOGIN_EMAIL'] ?? '';
    final autoPassword = dotenv.env['AUTO_LOGIN_PASSWORD'] ?? '';

    if (autoEmail.isNotEmpty && autoPassword.isNotEmpty) {
      debugPrint('OSD: Auto-login enabled for kiosk mode');

      // Set credentials and trigger auto-login
      _emailController.text = autoEmail;
      _passwordController.text = autoPassword;

      // Small delay to ensure widget is fully built
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _handleLogin();
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService.instance;
    final result = await authService.signInWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isAuthenticated) {
      // Fetch displays
      final displays = await authService.fetchOsdDisplays();

      if (!mounted) return;

      if (displays.isEmpty) {
        setState(() {
          _errorMessage = 'No displays available for this account.';
        });
      } else {
        // Try to auto-select a display
        final autoSelect = await authService.getAutoSelectDisplay(displays);

        if (autoSelect != null) {
          await authService.selectDisplay(autoSelect);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
          );
        } else {
          // Show display selection
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DisplaySelectionScreen()),
          );
        }
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Login failed';
      });
    }
  }

  /// Handle Google Sign-In (Android only)
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    final authService = AuthService.instance;
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    setState(() {
      _isGoogleLoading = false;
    });

    if (result.isAuthenticated) {
      // Fetch displays
      final displays = await authService.fetchOsdDisplays();

      if (!mounted) return;

      if (displays.isEmpty) {
        setState(() {
          _errorMessage = 'No displays available for this account.';
        });
      } else {
        // Try to auto-select a display
        final autoSelect = await authService.getAutoSelectDisplay(displays);

        if (autoSelect != null) {
          await authService.selectDisplay(autoSelect);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
          );
        } else {
          // Show display selection
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DisplaySelectionScreen()),
          );
        }
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Google login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 700;

    return Scaffold(
      backgroundColor: const Color(0xFFBBDEFB), // Blue-200 surface (OSD theme)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header section (Logo + Title)
                    _buildHeader(),

                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        constraints: BoxConstraints(maxWidth: isWideScreen ? 700 : 400),
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Login Cards - Side by side on wide screens
                    if (isWideScreen && Platform.isAndroid)
                      _buildTwoColumnLayout()
                    else
                      _buildSingleColumnLayout(),

                    const SizedBox(height: 24),

                    // Footer
                    const Text(
                      'Use your POS account to sign in',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // App Logo
        Image.asset(
          'assets/icons/app_icon.png',
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.monitor,
              size: 100,
              color: Color(0xFF2196F3),
            );
          },
        ),

        const SizedBox(height: 16),

        // App Title
        const Text(
          'Sciometa OSD',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        const Text(
          'Order Status Display',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Email Login
          Expanded(
            child: _buildEmailLoginCard(),
          ),

          const SizedBox(width: 24),

          // Right: Google Login
          Expanded(
            child: _buildGoogleLoginCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleColumnLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          _buildEmailLoginCard(),

          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildGoogleLoginCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBDEFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Email Sign In',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading && !_isGoogleLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
            ),
            obscureText: _obscurePassword,
            enabled: !_isLoading && !_isGoogleLoading,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Remember me checkbox
          CheckboxListTile(
            value: _rememberMe,
            onChanged: (_isLoading || _isGoogleLoading)
                ? null
                : (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
            title: const Text(
              'Auto-login next time',
              style: TextStyle(fontSize: 14),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF2196F3),
            dense: true,
          ),

          const SizedBox(height: 16),

          // Login button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.g_mobiledata,
                  color: Color(0xFF4285F4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Google Sign In',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick & Secure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sign in with your Google account linked to your POS system. No password required.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Google Sign-In button
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(
                  color: Color(0xFFD1D5DB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Colors.white,
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.google.com/favicon.ico',
                          height: 20,
                          width: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.g_mobiledata,
                              size: 24,
                              color: Color(0xFF4285F4),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
