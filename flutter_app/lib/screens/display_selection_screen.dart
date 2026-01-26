import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/osd_display.dart';
import 'order_status_screen.dart';
import 'login_screen.dart';

/// Display Selection Screen
///
/// Allows users to select which OSD display to use when multiple are available.
class DisplaySelectionScreen extends StatefulWidget {
  const DisplaySelectionScreen({super.key});

  @override
  State<DisplaySelectionScreen> createState() => _DisplaySelectionScreenState();
}

class _DisplaySelectionScreenState extends State<DisplaySelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectDisplay(OsdDisplay display) async {
    setState(() {
      _isLoading = true;
    });

    final authService = AuthService.instance;
    await authService.selectDisplay(display);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final authService = AuthService.instance;
    await authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    final displays = authService.availableDisplays;
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: const Text('Select Display'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D9FF),
              ),
            )
          : Column(
              children: [
                // User info
                if (user != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF16213E),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9FF).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF00D9FF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? user.email,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Display list
                Expanded(
                  child: displays.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monitor_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No displays available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displays.length,
                          itemBuilder: (context, index) {
                            final display = displays[index];
                            return _buildDisplayCard(display);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDisplayCard(OsdDisplay display) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFF00D9FF).withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _selectDisplay(display),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monitor,
                  color: Color(0xFF00D9FF),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (display.storeName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        display.storeName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
