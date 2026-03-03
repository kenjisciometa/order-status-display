import 'package:flutter/material.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_layout.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../services/api_client_service.dart';
import '../services/auth_service.dart';
import 'display_selection_screen.dart';
import 'order_status_screen.dart';

/// Initial Setup Screen
///
/// Displayed when the app is launched for the first time
/// or when no auto-login credentials are configured.
/// Allows users to enter their email and password for auto-login.
class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // First, test the credentials by logging in
    final authService = AuthService.instance;
    final result = await authService.signInWithEmailPassword(
      email: email,
      password: password,
      rememberMe: true, // Always remember for kiosk mode
    );

    if (!mounted) return;

    if (result.isAuthenticated) {
      // Credentials are valid, store them for auto-login
      final apiClient = ApiClientService.instance;
      await apiClient.setAutoLoginEnabled(true);
      await apiClient.storeCredentials(email, password);

      debugPrint('Initial setup: Credentials saved for auto-login');

      // Fetch displays and navigate
      final displays = await authService.fetchOsdDisplays();

      if (!mounted) return;

      if (displays.isEmpty) {
        setState(() {
          _isLoading = false;
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
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Login failed. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OsdLayout.setupBodyPadding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: OsdLayout.setupMaxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome header
                  _buildHeader(),

                  const SizedBox(height: OsdSpacing.space40),

                  // Step indicator
                  _buildStepIndicator(),

                  const SizedBox(height: OsdSpacing.space32),

                  // Main content based on step
                  _currentStep == 0 ? _buildWelcomeStep() : _buildCredentialsStep(),
                ],
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
        // Logo
        Container(
          padding: const EdgeInsets.all(OsdLayout.setupHeaderPadding),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F3460),
                Color(0xFF00D9FF),
              ],
            ),
            borderRadius: OsdRadius.borderRadiusXxl,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.settings_outlined,
            size: 72,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: OsdSpacing.space24),

        const Text(
          'Initial Setup',
          style: TextStyle(
            fontSize: OsdTypography.fontSize32,
            fontWeight: OsdTypography.weightBold,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: OsdSpacing.space8),

        Text(
          'Configure auto-login for your display',
          style: TextStyle(
            fontSize: OsdTypography.fontSize16,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(0, 'Welcome'),
        _buildStepConnector(),
        _buildStepDot(1, 'Credentials'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: OsdLayout.setupStepDotSize,
          height: OsdLayout.setupStepDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF00D9FF) : const Color(0xFF16213E),
            border: Border.all(
              color: isActive ? const Color(0xFF00D9FF) : Colors.white24,
              width: OsdLayout.inputFocusBorderWidth,
            ),
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, color: Colors.black, size: OsdIconSizes.size24)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: OsdTypography.fontSize18,
                      fontWeight: OsdTypography.weightBold,
                      color: isActive ? Colors.black : Colors.white54,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: OsdSpacing.space8),
        Text(
          label,
          style: TextStyle(
            fontSize: OsdTypography.fontSize14,
            color: isActive ? const Color(0xFF00D9FF) : Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: OsdLayout.setupStepConnectorWidth,
      height: OsdSpacing.space2,
      margin: const EdgeInsets.only(bottom: OsdSpacing.space24),
      color: _currentStep > 0 ? const Color(0xFF00D9FF) : Colors.white24,
    );
  }

  Widget _buildWelcomeStep() {
    return Container(
      padding: const EdgeInsets.all(OsdSpacing.space24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: OsdRadius.borderRadiusLg,
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Color(0xFF00D9FF),
                size: OsdIconSizes.size28,
              ),
              SizedBox(width: OsdSpacing.space12),
              Text(
                'Welcome to Sciometa OSD',
                style: TextStyle(
                  fontSize: OsdTypography.fontSize22,
                  fontWeight: OsdTypography.weightBold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: OsdSpacing.space20),

          Text(
            'This setup wizard will help you configure your Order Status Display for kiosk mode.',
            style: TextStyle(
              fontSize: OsdTypography.fontSize16,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),

          const SizedBox(height: OsdSpacing.space16),

          _buildFeatureItem(Icons.login, 'Auto-login on startup'),
          _buildFeatureItem(Icons.fullscreen, 'Fullscreen kiosk mode'),
          _buildFeatureItem(Icons.notifications_active, 'Real-time order updates'),

          const SizedBox(height: OsdSpacing.space24),

          SizedBox(
            width: double.infinity,
            height: OsdLayout.setupButtonHeight,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: OsdRadius.borderRadiusMd,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: OsdTypography.fontSize18,
                      fontWeight: OsdTypography.weightBold,
                    ),
                  ),
                  SizedBox(width: OsdSpacing.space8),
                  Icon(Icons.arrow_forward),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OsdSpacing.space8),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4CAF50),
            size: OsdIconSizes.size24,
          ),
          const SizedBox(width: OsdSpacing.space12),
          Text(
            text,
            style: TextStyle(
              fontSize: OsdTypography.fontSize16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsStep() {
    return Container(
      padding: const EdgeInsets.all(OsdSpacing.space24),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: OsdRadius.borderRadiusLg,
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Color(0xFF00D9FF),
                  size: OsdIconSizes.size28,
                ),
                SizedBox(width: OsdSpacing.space12),
                Text(
                  'Login Credentials',
                  style: TextStyle(
                    fontSize: OsdTypography.fontSize22,
                    fontWeight: OsdTypography.weightBold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: OsdSpacing.space8),

            Text(
              'Enter your Sciometa account credentials. These will be securely stored for automatic login.',
              style: TextStyle(
                fontSize: OsdTypography.fontSize14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: OsdSpacing.space24),

            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Email',
                icon: Icons.email_outlined,
              ),
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
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Password',
                icon: Icons.lock_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white54,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: OsdSpacing.space16),
              Container(
                padding: const EdgeInsets.all(OsdSpacing.space12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF44336).withOpacity(0.2),
                  borderRadius: OsdRadius.borderRadiusBase,
                  border: Border.all(
                    color: const Color(0xFFF44336).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFF44336),
                      size: OsdIconSizes.size20,
                    ),
                    const SizedBox(width: OsdSpacing.space8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFF44336),
                          fontSize: OsdTypography.fontSize14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: OsdSpacing.space24),

            // Buttons row
            Row(
              children: [
                // Back button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep = 0;
                      _errorMessage = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white54),
                  label: const Text(
                    'Back',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

                const Spacer(),

                // Setup button
                SizedBox(
                  height: OsdLayout.setupButtonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: OsdLayout.setupBodyPadding),
                      shape: RoundedRectangleBorder(
                        borderRadius: OsdRadius.borderRadiusMd,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: OsdSpacing.space24,
                            height: OsdSpacing.space24,
                            child: CircularProgressIndicator(
                              strokeWidth: OsdLayout.inputFocusBorderWidth,
                              color: Colors.black,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Complete Setup',
                                style: TextStyle(
                                  fontSize: OsdTypography.fontSize16,
                                  fontWeight: OsdTypography.weightBold,
                                ),
                              ),
                              SizedBox(width: OsdSpacing.space8),
                              Icon(Icons.check),
                            ],
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: OsdSpacing.space16),

            // Security note
            Container(
              padding: const EdgeInsets.all(OsdSpacing.space12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3460).withOpacity(0.5),
                borderRadius: OsdRadius.borderRadiusBase,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF00D9FF),
                    size: OsdIconSizes.size20,
                  ),
                  const SizedBox(width: OsdSpacing.space8),
                  Expanded(
                    child: Text(
                      'Your credentials are stored securely on this device and used only for automatic login.',
                      style: TextStyle(
                        fontSize: OsdTypography.fontSize12,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0F3460),
      border: OutlineInputBorder(
        borderRadius: OsdRadius.borderRadiusMd,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: OsdRadius.borderRadiusMd,
        borderSide: const BorderSide(
          color: Color(0xFF00D9FF),
          width: OsdLayout.inputFocusBorderWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: OsdRadius.borderRadiusMd,
        borderSide: const BorderSide(
          color: Color(0xFFF44336),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: OsdRadius.borderRadiusMd,
        borderSide: const BorderSide(
          color: Color(0xFFF44336),
          width: OsdLayout.inputFocusBorderWidth,
        ),
      ),
    );
  }
}
