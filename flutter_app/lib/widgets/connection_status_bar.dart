import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// Connection Status Bar Widget
///
/// Displays WebSocket connection status at the top of the screen.
/// Includes settings button for accessing app settings.
/// Minimal design without logo/branding.
class ConnectionStatusBar extends StatelessWidget {
  final bool isConnected;
  final VoidCallback? onSettingsTap;
  final String? errorMessage;

  const ConnectionStatusBar({
    super.key,
    required this.isConnected,
    this.onSettingsTap,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final isDarkMode = settingsService.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Connection status indicator (moved to left)
            _buildConnectionIndicator(isDarkMode),

            const Spacer(),

            // Settings button
            IconButton(
              onPressed: onSettingsTap,
              icon: Icon(
                Icons.settings,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(bool isDarkMode) {
    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF44336).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF44336).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFF44336),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFFF44336),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? const Color(0xFF4CAF50).withOpacity(0.2)
            : const Color(0xFFFF9800).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? const Color(0xFF4CAF50).withOpacity(0.5)
              : const Color(0xFFFF9800).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Reconnecting...',
            style: TextStyle(
              color: isConnected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
