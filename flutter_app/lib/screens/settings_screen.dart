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
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device info section
          _buildSectionHeader('DEVICE INFO'),
          _buildInfoCard([
            _buildInfoRow('Display Name', settingsService.deviceName ?? '-'),
            _buildInfoRow('Store ID', settingsService.storeId ?? '-'),
            _buildInfoRow('User', authService.currentUser?.email ?? '-'),
          ]),

          const SizedBox(height: 24),

          // Connection status section
          _buildSectionHeader('CONNECTION STATUS'),
          _buildInfoCard([
            _buildInfoRow(
              'WebSocket',
              webSocketService.isConnected ? 'Connected' : 'Disconnected',
              valueColor: webSocketService.isConnected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF44336),
            ),
            _buildInfoRow(
              'Notifications Received',
              '${webSocketService.notificationsReceived}',
            ),
            if (webSocketService.connectedAt != null)
              _buildInfoRow(
                'Connected At',
                _formatDateTime(webSocketService.connectedAt!),
              ),
          ]),

          const SizedBox(height: 24),

          // Appearance settings section
          _buildSectionHeader('APPEARANCE'),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Switch between dark and light theme',
            value: settingsService.isDarkMode,
            onChanged: (value) => settingsService.setDarkMode(value),
          ),

          const SizedBox(height: 24),

          // Display settings section
          _buildSectionHeader('DISPLAY SETTINGS'),
          _buildPrimaryDisplayTypeSelector(settingsService),
          const SizedBox(height: 8),
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

          const SizedBox(height: 24),

          // Sound settings section
          _buildSectionHeader('SOUND SETTINGS'),
          _buildSwitchTile(
            title: 'Ready Sound',
            subtitle: 'Play sound when order is ready',
            value: settingsService.playReadySound,
            onChanged: (value) {
              settingsService.setPlayReadySound(value);
              AudioService.instance.setSoundEnabled(value);
            },
          ),
          _buildSoundTypeSelector(settingsService),
          _buildActionTile(
            title: 'Test Sound',
            subtitle: 'Play ready sound for testing',
            icon: Icons.play_arrow,
            onTap: () => AudioService.instance.playOrderReadySound(),
          ),

          const SizedBox(height: 24),

          // Device control section
          _buildSectionHeader('DEVICE CONTROL'),
          _buildSwitchTile(
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
          _buildSliderTile(
            title: 'Screen Brightness',
            value: deviceService.brightness,
            onChanged: (value) => deviceService.setBrightness(value),
          ),

          const SizedBox(height: 24),

          // Logout section
          _buildSectionHeader('ACCOUNT'),
          _buildActionTile(
            title: 'Logout',
            subtitle: 'Sign out from this device',
            icon: Icons.logout,
            iconColor: const Color(0xFFF44336),
            onTap: _handleLogout,
          ),

          const SizedBox(height: 32),

          // Version info
          Center(
            child: Text(
              'Sciometa OSD v1.0.0',
              style: TextStyle(
                fontSize: 12,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00D9FF),
          letterSpacing: 1,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.white,
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
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00D9FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? const Color(0xFF00D9FF),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white54,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
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
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00D9FF),
            inactiveColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Build Sound Type selector
  Widget _buildSoundTypeSelector(SettingsService settingsService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sound Type',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select notification sound for ready orders',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReadySoundType.values.map((type) {
              final isSelected = settingsService.readySoundType == type;
              return InkWell(
                onTap: () {
                  settingsService.setReadySoundType(type);
                  // Play the sound when selected
                  AudioService.instance.playSoundType(type);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00D9FF), width: 1.5)
                        : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSoundIcon(type),
                        size: 18,
                        color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          fontSize: 14,
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
    final options = [
      (30, '30 seconds'),
      (60, '1 minute'),
      (120, '2 minutes'),
      (180, '3 minutes'),
      (300, '5 minutes'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready Order Highlight Duration',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Duration to highlight newly ready orders',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = currentSeconds == option.$1;
              return InkWell(
                onTap: () => settingsService.setHighlightDurationSeconds(option.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00D9FF), width: 1.5)
                        : Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    option.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white70,
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Number Type',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select the number type to display on cards',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00D9FF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D9FF), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00D9FF) : Colors.white54,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF00D9FF) : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
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
                size: 20,
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
