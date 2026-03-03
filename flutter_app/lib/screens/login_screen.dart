import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_layout.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
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
    final isWideScreen = screenWidth > OsdLayout.loginWideBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFBBDEFB), // Blue-200 surface (OSD theme)
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(OsdLayout.loginCardPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header section (Logo + Title)
                    _buildHeader(),

                    const SizedBox(height: OsdSpacing.space24),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        constraints: BoxConstraints(
                            maxWidth: isWideScreen
                                ? OsdLayout.loginWideBreakpoint
                                : OsdLayout.loginSingleColumnMaxWidth),
                        padding: const EdgeInsets.all(OsdSpacing.space12),
                        margin: const EdgeInsets.only(bottom: OsdSpacing.space16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: OsdRadius.borderRadiusBase,
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFDC2626),
                              size: OsdIconSizes.size20,
                            ),
                            const SizedBox(width: OsdSpacing.space8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: OsdTypography.fontSize14,
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

                    const SizedBox(height: OsdSpacing.space24),

                    // Footer
                    const Text(
                      'Use your POS account to sign in',
                      style: TextStyle(
                        fontSize: OsdTypography.fontSize12,
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
          width: OsdLayout.loginLogoSize,
          height: OsdLayout.loginLogoSize,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.monitor,
              size: OsdLayout.loginLogoSize,
              color: Color(0xFF2196F3),
            );
          },
        ),

        const SizedBox(height: OsdSpacing.space16),

        // App Title
        const Text(
          'Sciometa OSD',
          style: TextStyle(
            fontSize: OsdTypography.fontSize24,
            fontWeight: OsdTypography.weightBold,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: OsdSpacing.space4),

        const Text(
          'Order Status Display',
          style: TextStyle(
            fontSize: OsdTypography.fontSize14,
            color: Color(0xFF6B7280),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout() {
    return Container(
      constraints: const BoxConstraints(maxWidth: OsdLayout.loginTwoColumnMaxWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Email Login
          Expanded(
            child: _buildEmailLoginCard(),
          ),

          const SizedBox(width: OsdSpacing.space24),

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
      constraints: const BoxConstraints(maxWidth: OsdLayout.loginSingleColumnMaxWidth),
      child: Column(
        children: [
          _buildEmailLoginCard(),

          if (Platform.isAndroid) ...[
            const SizedBox(height: OsdSpacing.space16),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space16),
                  child: const Text(
                    'or',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: OsdTypography.fontSize14,
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

            const SizedBox(height: OsdSpacing.space16),

            _buildGoogleLoginCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailLoginCard() {
    return Container(
      padding: const EdgeInsets.all(OsdLayout.loginCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
                padding: const EdgeInsets.all(OsdSpacing.space8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBBDEFB),
                  borderRadius: OsdRadius.borderRadiusBase,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF2196F3),
                  size: OsdIconSizes.size20,
                ),
              ),
              const SizedBox(width: OsdSpacing.space12),
              const Text(
                'Email Sign In',
                style: TextStyle(
                  fontSize: OsdTypography.fontSize18,
                  fontWeight: OsdTypography.weightSemibold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: OsdSpacing.space20),

          // Email field
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: OsdRadius.borderRadiusBase,
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

          const SizedBox(height: OsdSpacing.space16),

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
                borderRadius: OsdRadius.borderRadiusBase,
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

          const SizedBox(height: OsdSpacing.space12),

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
              style: TextStyle(fontSize: OsdTypography.fontSize14),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFF2196F3),
            dense: true,
          ),

          const SizedBox(height: OsdSpacing.space16),

          // Login button
          SizedBox(
            height: OsdLayout.buttonHeight,
            child: ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: OsdRadius.borderRadiusBase,
                ),
                elevation: OsdElevation.level2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: OsdIconSizes.size20,
                      width: OsdIconSizes.size20,
                      child: CircularProgressIndicator(
                        strokeWidth: OsdSpacing.space2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: OsdTypography.fontSize16,
                        fontWeight: OsdTypography.weightSemibold,
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
      padding: const EdgeInsets.all(OsdLayout.loginCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
                padding: const EdgeInsets.all(OsdSpacing.space8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF5FF),
                  borderRadius: OsdRadius.borderRadiusBase,
                ),
                child: const Icon(
                  Icons.g_mobiledata,
                  color: Color(0xFF4285F4),
                  size: OsdIconSizes.size20,
                ),
              ),
              const SizedBox(width: OsdSpacing.space12),
              const Text(
                'Google Sign In',
                style: TextStyle(
                  fontSize: OsdTypography.fontSize18,
                  fontWeight: OsdTypography.weightSemibold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: OsdSpacing.space20),

          // Description
          Container(
            padding: const EdgeInsets.all(OsdSpacing.space16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: OsdRadius.borderRadiusBase,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick & Secure',
                  style: TextStyle(
                    fontSize: OsdTypography.fontSize14,
                    fontWeight: OsdTypography.weightSemibold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: OsdSpacing.space8),
                const Text(
                  'Sign in with your Google account linked to your POS system. No password required.',
                  style: TextStyle(
                    fontSize: OsdTypography.fontSize13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: OsdSpacing.space20),

          // Google Sign-In button
          SizedBox(
            height: OsdLayout.buttonHeight,
            child: OutlinedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(
                  color: Color(0xFFD1D5DB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: OsdRadius.borderRadiusBase,
                ),
                backgroundColor: Colors.white,
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      height: OsdIconSizes.size20,
                      width: OsdIconSizes.size20,
                      child: CircularProgressIndicator(
                        strokeWidth: OsdSpacing.space2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.google.com/favicon.ico',
                          height: OsdIconSizes.size20,
                          width: OsdIconSizes.size20,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.g_mobiledata,
                              size: OsdIconSizes.size24,
                              color: Color(0xFF4285F4),
                            );
                          },
                        ),
                        const SizedBox(width: OsdSpacing.space12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: OsdTypography.fontSize16,
                            fontWeight: OsdTypography.weightMedium,
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
