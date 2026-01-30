import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';
import '../services/device_control_service.dart';
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
  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final authService = Provider.of<AuthService>(context);
    final deviceService = Provider.of<DeviceControlService>(context);
    final webSocketService = OsdWebSocketService.instance;
    final isDarkMode = settingsService.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF0F3460) : const Color(0xFF2196F3),
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
          // Row 1: Device Info & Appearance
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('DEVICE INFO'),
                    _buildInfoCard([
                      _buildInfoRow('Display Name', settingsService.deviceName ?? '-'),
                      _buildInfoRow('Store ID', settingsService.storeId ?? '-'),
                      _buildInfoRow('User', authService.currentUser?.email ?? '-'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('APPEARANCE'),
                    _buildSwitchTile(
                      title: 'Dark Mode',
                      subtitle: 'Switch between dark and light theme',
                      value: settingsService.isDarkMode,
                      onChanged: (value) => settingsService.setDarkMode(value),
                    ),
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
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSliderTile(
                  title: 'Screen Brightness',
                  value: deviceService.brightness,
                  onChanged: (value) => deviceService.setBrightness(value),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Row 3: Display Settings (full width - complex section)
          _buildSectionHeader('DISPLAY SETTINGS'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPrimaryDisplayTypeSelector(settingsService),
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
                    ),
                    _buildSwitchTile(
                      title: "Show Elapsed Time (It's Ready)",
                      subtitle: "Display elapsed time on It's Ready cards",
                      value: settingsService.showElapsedTimeReady,
                      onChanged: (value) => settingsService.setShowElapsedTimeReady(value),
                    ),
                    _buildHighlightDurationSelector(settingsService),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Row 4: Sound Settings (full width - 2 columns)
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
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildSoundTypeSelectorWithTest(settingsService),
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
                color: Colors.white.withOpacity(0.4),
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
          color: Color(0xFF00D9FF),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 22,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.white,
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00D9FF),
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.7),
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
              activeColor: const Color(0xFF00D9FF),
              inactiveColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Sound Type selector with Test Sound button inside
  Widget _buildSoundTypeSelectorWithTest(SettingsService settingsService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sound Type',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.6),
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
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00D9FF), width: 2)
                        : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSoundIcon(type),
                        size: 28,
                        color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
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
  Widget _buildHighlightDurationSelector(SettingsService settingsService) {
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
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready Order Highlight Duration',
            style: TextStyle(
              fontSize: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Duration to highlight newly ready orders',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.6),
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
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00D9FF), width: 2)
                            : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Center(
                        child: Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
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
  Widget _buildPrimaryDisplayTypeSelector(SettingsService settingsService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Number Type',
            style: TextStyle(
              fontSize: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select the number type to display on cards',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.callNumber,
            'Call Number',
            'Customer pickup number (Recommended)',
            Icons.dialpad,
          ),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.tableNumber,
            'Table Number',
            'For table service',
            Icons.table_restaurant,
          ),
          _buildDisplayTypeOption(
            settingsService,
            PrimaryDisplayType.orderNumber,
            'Order Number',
            'System order ID',
            Icons.receipt_long,
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
              color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
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
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.5),
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
