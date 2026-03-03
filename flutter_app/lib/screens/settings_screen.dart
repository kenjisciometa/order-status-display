import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../services/device_control_service.dart';
import '../services/api_client_service.dart';
import '../services/osd_websocket_service.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_layout.dart';
import '../core/theme/app_icons.dart';
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
        toolbarHeight: OsdLayout.settingsAppBarHeight,
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: OsdTypography.fontSize32, fontWeight: OsdTypography.weightBold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: OsdIconSizes.size32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Connection Status indicator
          Padding(
            padding: const EdgeInsets.only(right: OsdSpacing.space8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space12, vertical: OsdSpacing.space6),
              decoration: BoxDecoration(
                color: webSocketService.isConnected
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : const Color(0xFFF44336).withOpacity(0.2),
                borderRadius: OsdRadius.borderRadiusXl,
                border: Border.all(
                  color: webSocketService.isConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                  width: OsdSpacing.space2,
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
                    size: OsdIconSizes.size24,
                  ),
                  const SizedBox(width: OsdSpacing.space8),
                  Text(
                    webSocketService.isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: webSocketService.isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                      fontSize: OsdTypography.fontSize18,
                      fontWeight: OsdTypography.weightBold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logout button
          Padding(
            padding: const EdgeInsets.only(right: OsdSpacing.space16),
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFF44336), size: OsdIconSizes.size28),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFF44336),
                  fontSize: OsdTypography.fontSize20,
                  fontWeight: OsdTypography.weightBold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF44336).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space16, vertical: OsdSpacing.space8),
                shape: RoundedRectangleBorder(
                  borderRadius: OsdRadius.borderRadiusMd,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(OsdLayout.settingsListPadding),
        children: [
          // Row 1: Auto Login Settings (moved to top)
          _buildSectionHeader('AUTO LOGIN SETTINGS'),
          _buildAutoLoginSection(),

          const SizedBox(height: OsdLayout.settingsSectionGap),

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

          const SizedBox(height: OsdLayout.settingsSectionGap),

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
              const SizedBox(width: OsdLayout.settingsSectionGap),
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

          const SizedBox(height: OsdLayout.settingsSectionGap),

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
              const SizedBox(width: OsdLayout.settingsSectionGap),
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

          const SizedBox(height: OsdLayout.settingsSectionGap),

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
              const SizedBox(width: OsdLayout.settingsSectionGap),
              Expanded(
                child: Column(
                  children: [
                    _buildSoundTypeSelectorWithTest(settingsService, isDarkMode),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: OsdSpacing.space32),

          // Logout button at bottom
          Center(
            child: SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: OsdIconSizes.size28),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: OsdTypography.fontSize24, fontWeight: OsdTypography.weightBold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space32, vertical: OsdSpacing.space16),
                  shape: RoundedRectangleBorder(
                    borderRadius: OsdRadius.borderRadiusLg,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: OsdLayout.settingsSectionGap),

          // Version info
          Center(
            child: Text(
              'Sciometa OSD v1.0.0',
              style: TextStyle(
                fontSize: OsdTypography.fontSize18,
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
      padding: const EdgeInsets.only(bottom: OsdSpacing.space16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: OsdTypography.fontSize24,
          fontWeight: OsdTypography.weightBold,
          color: Color(0xFF2196F3),
          letterSpacing: OsdTypography.letterSpacing15,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusMd,
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
      padding: const EdgeInsets.symmetric(horizontal: OsdLayout.settingsCardPadding, vertical: OsdSpacing.space16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: OsdTypography.fontSize22,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: OsdTypography.fontSize22,
                fontWeight: OsdTypography.weightMedium,
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
      margin: const EdgeInsets.only(bottom: OsdLayout.settingsCardMarginBottom),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
        border: isDarkMode
            ? null
            : Border.all(color: Colors.grey.shade300),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: OsdLayout.settingsCardPadding, vertical: OsdSpacing.space8),
        title: Text(
          title,
          style: TextStyle(
            fontSize: OsdTypography.fontSize26,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: OsdTypography.fontSize18,
            color: isDarkMode
                ? Colors.white.withOpacity(0.6)
                : Colors.grey.shade600,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2196F3),
        shape: RoundedRectangleBorder(
          borderRadius: OsdRadius.borderRadiusLg,
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
      margin: const EdgeInsets.only(bottom: OsdLayout.settingsCardMarginBottom),
      padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
                  fontSize: OsdTypography.fontSize26,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: OsdTypography.fontSize24,
                  fontWeight: OsdTypography.weightBold,
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: OsdSpacing.space12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: OsdSpacing.space14),
              trackHeight: OsdSpacing.space8,
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
      margin: const EdgeInsets.only(bottom: OsdLayout.settingsCardMarginBottom),
      padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
                  fontSize: OsdTypography.fontSize26,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              // Test Sound button
              ElevatedButton.icon(
                onPressed: () => AudioService.instance.playOrderReadySound(),
                icon: const Icon(Icons.play_arrow, size: OsdIconSizes.size24),
                label: const Text(
                  'Test',
                  style: TextStyle(fontSize: OsdTypography.fontSize18, fontWeight: OsdTypography.weightBold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space16, vertical: OsdSpacing.space8),
                  shape: RoundedRectangleBorder(
                    borderRadius: OsdRadius.borderRadiusR10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OsdSpacing.space6),
          Text(
            'Select notification sound for ready orders',
            style: TextStyle(
              fontSize: OsdTypography.fontSize18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: OsdSpacing.space16),
          Wrap(
            spacing: OsdSpacing.space12,
            runSpacing: OsdSpacing.space12,
            children: ReadySoundType.values.map((type) {
              final isSelected = settingsService.readySoundType == type;
              return InkWell(
                onTap: () {
                  settingsService.setReadySoundType(type);
                  // Play the sound when selected
                  AudioService.instance.playSoundType(type);
                },
                borderRadius: OsdRadius.borderRadiusMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space24, vertical: OsdSpacing.space16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.shade100),
                    borderRadius: OsdRadius.borderRadiusMd,
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00D9FF), width: OsdSpacing.space2)
                        : Border.all(color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSoundIcon(type),
                        size: OsdIconSizes.size28,
                        color: isSelected
                            ? const Color(0xFF00D9FF)
                            : (isDarkMode ? Colors.white70 : Colors.grey.shade700),
                      ),
                      const SizedBox(width: OsdSpacing.space12),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: OsdTypography.fontSize22,
                          fontWeight: isSelected ? OsdTypography.weightBold : OsdTypography.weightNormal,
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
      margin: const EdgeInsets.only(bottom: OsdLayout.settingsCardMarginBottom),
      padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
              fontSize: OsdTypography.fontSize26,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: OsdSpacing.space6),
          Text(
            'Duration to highlight newly ready orders',
            style: TextStyle(
              fontSize: OsdTypography.fontSize18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: OsdSpacing.space16),
          Row(
            children: options.map((option) {
              final isSelected = currentSeconds == option.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space4),
                  child: InkWell(
                    onTap: () => settingsService.setHighlightDurationSeconds(option.$1),
                    borderRadius: OsdRadius.borderRadiusR10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: OsdSpacing.space14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100),
                        borderRadius: OsdRadius.borderRadiusR10,
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00D9FF), width: OsdSpacing.space2)
                            : Border.all(color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: OsdTypography.fontSize20,
                            fontWeight: isSelected ? OsdTypography.weightBold : OsdTypography.weightNormal,
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
      margin: const EdgeInsets.only(bottom: OsdLayout.settingsCardMarginBottom),
      padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
              fontSize: OsdTypography.fontSize26,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: OsdSpacing.space6),
          Text(
            'Select the number type to display on cards',
            style: TextStyle(
              fontSize: OsdTypography.fontSize18,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: OsdSpacing.space16),
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
      borderRadius: OsdRadius.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space16, vertical: OsdSpacing.space14),
        margin: const EdgeInsets.only(bottom: OsdSpacing.space8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: OsdRadius.borderRadiusMd,
          border: isSelected
              ? Border.all(color: const Color(0xFF00D9FF), width: OsdSpacing.space2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF00D9FF)
                  : (isDarkMode ? Colors.white54 : Colors.grey.shade600),
              size: OsdIconSizes.size32,
            ),
            const SizedBox(width: OsdSpacing.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: OsdTypography.fontSize22,
                      fontWeight: isSelected ? OsdTypography.weightBold : OsdTypography.weightNormal,
                      color: isSelected
                          ? const Color(0xFF00D9FF)
                          : (isDarkMode ? Colors.white : const Color(0xFF1A1A2E)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: OsdTypography.fontSize16,
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
                size: OsdIconSizes.size28,
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
        padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: OsdRadius.borderRadiusLg,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D9FF),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(OsdLayout.settingsCardPadding),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF16213E) : Colors.white,
        borderRadius: OsdRadius.borderRadiusLg,
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
                size: OsdIconSizes.size28,
              ),
              const SizedBox(width: OsdSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAutoLoginEnabled ? 'Auto Login Enabled' : 'Auto Login Disabled',
                      style: TextStyle(
                        fontSize: OsdTypography.fontSize22,
                        fontWeight: OsdTypography.weightBold,
                        color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    if (_storedEmail != null && _isAutoLoginEnabled)
                      Text(
                        'Account: $_storedEmail',
                        style: TextStyle(
                          fontSize: OsdTypography.fontSize16,
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

          const SizedBox(height: OsdSpacing.space20),

          // Description
          Text(
            _isAutoLoginEnabled
                ? 'The app will automatically log in with the saved credentials when started.'
                : 'Enable auto login to automatically sign in when the app starts.',
            style: TextStyle(
              fontSize: OsdTypography.fontSize16,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.7)
                  : Colors.grey.shade700,
            ),
          ),

          const SizedBox(height: OsdSpacing.space20),

          // Action buttons
          Wrap(
            spacing: OsdSpacing.space12,
            runSpacing: OsdSpacing.space12,
            children: [
              if (_isAutoLoginEnabled) ...[
                // Change credentials button
                ElevatedButton.icon(
                  onPressed: () => _showChangeCredentialsDialog(),
                  icon: const Icon(Icons.edit, size: OsdIconSizes.size20),
                  label: const Text(
                    'Change Credentials',
                    style: TextStyle(fontSize: OsdTypography.fontSize16, fontWeight: OsdTypography.weightBold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space20, vertical: OsdSpacing.space12),
                    shape: RoundedRectangleBorder(
                      borderRadius: OsdRadius.borderRadiusR10,
                    ),
                  ),
                ),
                // Disable auto login button
                OutlinedButton.icon(
                  onPressed: () => _showDisableAutoLoginDialog(),
                  icon: const Icon(Icons.power_settings_new, size: OsdIconSizes.size20),
                  label: const Text(
                    'Disable Auto Login',
                    style: TextStyle(fontSize: OsdTypography.fontSize16, fontWeight: OsdTypography.weightBold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF44336),
                    side: const BorderSide(color: Color(0xFFF44336)),
                    padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space20, vertical: OsdSpacing.space12),
                    shape: RoundedRectangleBorder(
                      borderRadius: OsdRadius.borderRadiusR10,
                    ),
                  ),
                ),
              ] else ...[
                // Enable auto login button
                ElevatedButton.icon(
                  onPressed: () => _showEnableAutoLoginDialog(),
                  icon: const Icon(Icons.login, size: OsdIconSizes.size20),
                  label: const Text(
                    'Enable Auto Login',
                    style: TextStyle(fontSize: OsdTypography.fontSize16, fontWeight: OsdTypography.weightBold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space20, vertical: OsdSpacing.space12),
                    shape: RoundedRectangleBorder(
                      borderRadius: OsdRadius.borderRadiusR10,
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
    final scrollController = ScrollController();
    final emailFocusNode = FocusNode();
    final passwordFocusNode = FocusNode();
    bool isLoading = false;
    bool obscurePassword = true;
    String? errorMessage;

    // Helper to scroll to focused field
    void scrollToFocused() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    emailFocusNode.addListener(() {
      if (emailFocusNode.hasFocus) scrollToFocused();
    });
    passwordFocusNode.addListener(() {
      if (passwordFocusNode.hasFocus) scrollToFocused();
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: OsdRadius.borderRadiusLg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OsdLayout.dialogMaxWidth, maxHeight: OsdLayout.dialogMaxHeight),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(OsdLayout.dialogPadding),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Row(
                      children: [
                        Icon(Icons.login, color: Color(0xFF00D9FF)),
                        SizedBox(width: OsdSpacing.space12),
                        Text(
                          'Enable Auto Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: OsdTypography.fontSize20,
                            fontWeight: OsdTypography.weightBold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OsdSpacing.space16),
                    Text(
                      'Enter credentials to save for automatic login.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: OsdTypography.fontSize14,
                      ),
                    ),
                    const SizedBox(height: OsdSpacing.space20),
                    TextFormField(
                      controller: emailController,
                      focusNode: emailFocusNode,
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
                    const SizedBox(height: OsdSpacing.space16),
                    TextFormField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
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
                      const SizedBox(height: OsdSpacing.space16),
                      Container(
                        padding: const EdgeInsets.all(OsdSpacing.space12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336).withOpacity(0.2),
                          borderRadius: OsdRadius.borderRadiusBase,
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
                                errorMessage!,
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
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: OsdSpacing.space12),
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
                                  width: OsdSpacing.space20,
                                  height: OsdSpacing.space20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: OsdSpacing.space2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Enable'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Clean up
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    scrollController.dispose();
  }

  /// Show dialog to change auto login credentials
  Future<void> _showChangeCredentialsDialog() async {
    final apiClient = ApiClientService.instance;
    final currentEmail = await apiClient.getStoredEmail();

    final emailController = TextEditingController(text: currentEmail);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scrollController = ScrollController();
    final emailFocusNode = FocusNode();
    final passwordFocusNode = FocusNode();
    bool isLoading = false;
    bool obscurePassword = true;
    String? errorMessage;

    if (!mounted) return;

    // Helper to scroll to focused field
    void scrollToFocused() {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    emailFocusNode.addListener(() {
      if (emailFocusNode.hasFocus) scrollToFocused();
    });
    passwordFocusNode.addListener(() {
      if (passwordFocusNode.hasFocus) scrollToFocused();
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(
            borderRadius: OsdRadius.borderRadiusLg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OsdLayout.dialogMaxWidth, maxHeight: OsdLayout.dialogMaxHeight),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(OsdLayout.dialogPadding),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Row(
                      children: [
                        Icon(Icons.edit, color: Color(0xFF00D9FF)),
                        SizedBox(width: OsdSpacing.space12),
                        Text(
                          'Change Credentials',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: OsdTypography.fontSize20,
                            fontWeight: OsdTypography.weightBold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OsdSpacing.space16),
                    Text(
                      'Enter new credentials for automatic login.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: OsdTypography.fontSize14,
                      ),
                    ),
                    const SizedBox(height: OsdSpacing.space20),
                    TextFormField(
                      controller: emailController,
                      focusNode: emailFocusNode,
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
                    const SizedBox(height: OsdSpacing.space16),
                    TextFormField(
                      controller: passwordController,
                      focusNode: passwordFocusNode,
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
                      const SizedBox(height: OsdSpacing.space16),
                      Container(
                        padding: const EdgeInsets.all(OsdSpacing.space12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336).withOpacity(0.2),
                          borderRadius: OsdRadius.borderRadiusBase,
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
                                errorMessage!,
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
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: OsdSpacing.space12),
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
                                  width: OsdSpacing.space20,
                                  height: OsdSpacing.space20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: OsdSpacing.space2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Clean up
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    scrollController.dispose();
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
            SizedBox(width: OsdSpacing.space12),
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
