import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../services/device_control_service.dart';
import '../services/api_client_service.dart';
import '../services/osd_websocket_service.dart';
import 'login_screen.dart';

/// Settings Screen
///
/// Allows users to configure OSD display settings.
/// Related sections are displayed side by side for easier viewing.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isAutoLoginEnabled = false;
  String? _storedEmail;
  bool _isLoadingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _loadAutoLoginSettings();
  }

  Future<void> _loadAutoLoginSettings() async {
    final apiClient = ApiClientService.instance;
    final isEnabled = await apiClient.isAutoLoginEnabled();
    final email = await apiClient.getStoredEmail();

    if (mounted) {
      setState(() {
        _isAutoLoginEnabled = isEnabled;
        _storedEmail = email;
        _isLoadingAutoLogin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final authService = Provider.of<AuthService>(context);
    final deviceService = Provider.of<DeviceControlService>(context);
    final webSocketService = OsdWebSocketService.instance;
    // Always use light mode (white-based UI like KDS)
    const isDarkMode = false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        toolbarHeight: 80,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Connection Status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: webSocketService.isConnected
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : const Color(0xFFF44336).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: webSocketService.isConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    webSocketService.isConnected ? Icons.wifi : Icons.wifi_off,
                    color: webSocketService.isConnected
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    webSocketService.isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: webSocketService.isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logout button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFF44336), size: 28),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFF44336),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF44336).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Row 1: Auto Login Settings (moved to top)
          _buildSectionHeader('AUTO LOGIN SETTINGS'),
          _buildAutoLoginSection(),

          const SizedBox(height: 24),

          // Row 2: Device Info & Appearance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('DEVICE INFO'),
                    _buildInfoCard([
                      _buildInfoRow('Display Name', settingsService.deviceName ?? '-', isDarkMode),
                      _buildInfoRow('Store ID', settingsService.storeId ?? '-', isDarkMode),
                      _buildInfoRow('User', authService.currentUser?.email ?? '-', isDarkMode),
                    ], isDarkMode),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Row 2: Device Control (2 components in 1 row)
          _buildSectionHeader('DEVICE CONTROL'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildSwitchTile(
                  title: 'Prevent Screen Sleep',
                  subtitle: 'Keep the screen awake',
                  value: deviceService.wakeLockEnabled,
                  onChanged: (value) {
                    if (value) {
                      deviceService.enableWakeLock();
                    } else {
                      deviceService.disableWakeLock();
                    }
                  },
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSliderTile(
                  title: 'Screen Brightness',
                  value: deviceService.brightness,
                  onChanged: (value) => deviceService.setBrightness(value),
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Row 4: Display Settings (full width - complex section)
          _buildSectionHeader('DISPLAY SETTINGS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPrimaryDisplayTypeSelector(settingsService, isDarkMode),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Show Elapsed Time (Now Cooking)',
                      subtitle: 'Display elapsed time on Now Cooking cards',
                      value: settingsService.showElapsedTimeNowCooking,
                      onChanged: (value) => settingsService.setShowElapsedTimeNowCooking(value),
                      isDarkMode: isDarkMode,
                    ),
                    _buildSwitchTile(
                      title: "Show Elapsed Time (It's Ready)",
                      subtitle: "Display elapsed time on It's Ready cards",
                      value: settingsService.showElapsedTimeReady,
                      onChanged: (value) => settingsService.setShowElapsedTimeReady(value),
                      isDarkMode: isDarkMode,
                    ),
                    _buildHighlightDurationSelector(settingsService, isDarkMode),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Row 6: Sound Settings (full width - 2 columns)
          _buildSectionHeader('SOUND SETTINGS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Ready Sound',
                      subtitle: 'Play sound when order is ready',
                      value: settingsService.playReadySound,
                      onChanged: (value) {
                        settingsService.setPlayReadySound(value);
                        AudioService.instance.setSoundEnabled(value);
                      },
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildSoundTypeSelectorWithTest(settingsService, isDarkMode),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Logout button at bottom
          Center(
            child: SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 28),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Version info
          Center(
            child: Text(
              'Sciometa OSD v1.0.0',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2196F3),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF00D9FF).withOpacity(0.2)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDarkMode, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 22,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: valueColor ?? (isDarkMode ? Colors.white : const Color(0xFF1A1A2E)),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 26,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 18,
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : Colors.grey.shade600,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2196F3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              trackHeight: 8,
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF2196F3),
              inactiveColor: isDarkMode ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Sound Type selector with Test Sound button inside
  Widget _buildSoundTypeSelectorWithTest(SettingsService settingsService, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sound Type',
                style: TextStyle(
                  fontSize: 26,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              // Test Sound button
              ElevatedButton.icon(
                onPressed: () => AudioService.instance.playOrderReadySound(),
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Test',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select notification sound for ready orders',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ReadySoundType.values.map((type) {
              final isSelected = settingsService.readySoundType == type;
              return InkWell(
                onTap: () {
                  settingsService.setReadySoundType(type);
                  // Play the sound when selected
                  AudioService.instance.playSoundType(type);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00D9FF), width: 2)
                        : Border.all(color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSoundIcon(type),
                        size: 28,
                        color: isSelected
                            ? const Color(0xFF00D9FF)
                            : (isDarkMode ? Colors.white70 : Colors.grey.shade700),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF00D9FF)
                              : (isDarkMode ? Colors.white70 : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _getSoundIcon(ReadySoundType type) {
    switch (type) {
      case ReadySoundType.slick:
        return Icons.notifications_active;
      case ReadySoundType.bell:
        return Icons.notifications;
      case ReadySoundType.quick:
        return Icons.flash_on;
    }
  }

  /// Build Highlight Duration selector for newly ready orders
  Widget _buildHighlightDurationSelector(SettingsService settingsService, bool isDarkMode) {
    final currentSeconds = settingsService.highlightDurationSeconds;
    // Options: 30 seconds, 1 minute, 2 minutes, 3 minutes, 5 minutes
    // Short labels to fit in one row
    final options = [
      (30, '30s'),
      (60, '1m'),
      (120, '2m'),
      (180, '3m'),
      (300, '5m'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ready Order Highlight Duration',
            style: TextStyle(
              fontSize: 26,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Duration to highlight newly ready orders',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: options.map((option) {
              final isSelected = currentSeconds == option.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => settingsService.setHighlightDurationSeconds(option.$1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00D9FF), width: 2)
                            : Border.all(color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF00D9FF)
                                : (isDarkMode ? Colors.white70 : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Build Primary Display Type selector (F-009)
  Widget _buildPrimaryDisplayTypeSelector(SettingsService settingsService, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display Number Type',
            style: TextStyle(
              fontSize: 26,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the number type to display on cards',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.callNumber,
            'Call Number',
            'Customer pickup number (Recommended)',
            Icons.dialpad,
            isDarkMode,
          ),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.tableNumber,
            'Table Number',
            'For table service',
            Icons.table_restaurant,
            isDarkMode,
          ),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.orderNumber,
            'Order Number',
            'System order ID',
            Icons.receipt_long,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayTypeOption(
    SettingsService settingsService,
    PrimaryDisplayType type,
    String title,
    String subtitle,
    IconData icon,
    bool isDarkMode,
  ) {
    final isSelected = settingsService.primaryDisplayType == type;
    return InkWell(
      onTap: () => settingsService.setPrimaryDisplayType(type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D9FF), width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF00D9FF)
                  : (isDarkMode ? Colors.white54 : Colors.grey.shade600),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? const Color(0xFF00D9FF)
                          : (isDarkMode ? Colors.white : const Color(0xFF1A1A2E)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00D9FF),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  /// Build Auto Login settings section
  Widget _buildAutoLoginSection() {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final isDarkMode = settingsService.isDarkMode;

    if (_isLoadingAutoLogin) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D9FF),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF00D9FF).withOpacity(0.2)
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              Icon(
                _isAutoLoginEnabled ? Icons.check_circle : Icons.cancel,
                color: _isAutoLoginEnabled
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAutoLoginEnabled ? 'Auto Login Enabled' : 'Auto Login Disabled',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    if (_storedEmail != null && _isAutoLoginEnabled)
                      Text(
                        'Account: $_storedEmail',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.6)
                              : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            _isAutoLoginEnabled
                ? 'The app will automatically log in with the saved credentials when started.'
                : 'Enable auto login to automatically sign in when the app starts.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_isAutoLoginEnabled) ...[
                // Change credentials button
                ElevatedButton.icon(
                  onPressed: () => _showChangeCredentialsDialog(),
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text(
                    'Change Credentials',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Disable auto login button
                OutlinedButton.icon(
                  onPressed: () => _showDisableAutoLoginDialog(),
                  icon: const Icon(Icons.power_settings_new, size: 20),
                  label: const Text(
                    'Disable Auto Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF44336),
                    side: const BorderSide(color: Color(0xFFF44336)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ] else ...[
                // Enable auto login button
                ElevatedButton.icon(
                  onPressed: () => _showEnableAutoLoginDialog(),
                  icon: const Icon(Icons.login, size: 20),
                  label: const Text(
                    'Enable Auto Login',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Show dialog to enable auto login
  Future<void> _showEnableAutoLoginDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscurePassword = true;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Row(
            children: [
              Icon(Icons.login, color: Color(0xFF00D9FF)),
              SizedBox(width: 12),
              Text(
                'Enable Auto Login',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter credentials to save for automatic login.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Email', Icons.email_outlined),
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
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Password',
                      Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
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
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFF44336),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFF44336),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      // Test credentials
                      final authService = AuthService.instance;
                      final result = await authService.signInWithEmailPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        rememberMe: true,
                      );

                      if (result.isAuthenticated) {
                        // Save credentials
                        final apiClient = ApiClientService.instance;
                        await apiClient.setAutoLoginEnabled(true);
                        await apiClient.storeCredentials(
                          emailController.text.trim(),
                          passwordController.text,
                        );

                        Navigator.of(context).pop();

                        // Refresh state
                        await _loadAutoLoginSettings();

                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Auto login enabled successfully'),
                              backgroundColor: Color(0xFF4CAF50),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = result.errorMessage ?? 'Invalid credentials';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Enable'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to change auto login credentials
  Future<void> _showChangeCredentialsDialog() async {
    final apiClient = ApiClientService.instance;
    final currentEmail = await apiClient.getStoredEmail();

    final emailController = TextEditingController(text: currentEmail);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscurePassword = true;
    String? errorMessage;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF00D9FF)),
              SizedBox(width: 12),
              Text(
                'Change Credentials',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter new credentials for automatic login.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration('Email', Icons.email_outlined),
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
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Password',
                      Icons.lock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscurePassword = !obscurePassword;
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
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFF44336),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFF44336),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      // Test new credentials
                      final authService = AuthService.instance;
                      final result = await authService.signInWithEmailPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                        rememberMe: true,
                      );

                      if (result.isAuthenticated) {
                        // Update stored credentials
                        final apiClient = ApiClientService.instance;
                        await apiClient.storeCredentials(
                          emailController.text.trim(),
                          passwordController.text,
                        );

                        Navigator.of(context).pop();

                        // Refresh state
                        await _loadAutoLoginSettings();

                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Credentials updated successfully'),
                              backgroundColor: Color(0xFF4CAF50),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = result.errorMessage ?? 'Invalid credentials';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to disable auto login
  Future<void> _showDisableAutoLoginDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFFF9800)),
            SizedBox(width: 12),
            Text(
              'Disable Auto Login',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to disable auto login? You will need to manually log in each time the app starts.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apiClient = ApiClientService.instance;
      await apiClient.clearCredentials();

      await _loadAutoLoginSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto login disabled'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    }
  }

  /// Input decoration for dialogs
  InputDecoration _dialogInputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Colors.white54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF0F3460),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF00D9FF),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFF44336),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFF44336),
          width: 2,
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await OsdWebSocketService.instance.disconnect();
      await AuthService.instance.signOut();
      await SettingsService.instance.clearSettings();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
