import 'package:flutter/material.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_layout.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../services/auth_service.dart';
import '../models/display_preset.dart';
import 'order_status_screen.dart';
import 'login_screen.dart';

/// Display Selection Screen
///
/// Allows users to select which OSD display to use when multiple are available.
/// Displays are grouped by store for easier navigation.
/// White-based UI like KDS (only header is colored).
class DisplaySelectionScreen extends StatefulWidget {
  const DisplaySelectionScreen({super.key});

  @override
  State<DisplaySelectionScreen> createState() => _DisplaySelectionScreenState();
}

class _DisplaySelectionScreenState extends State<DisplaySelectionScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If displays haven't been fetched yet, fetch them
    if (_authService.availableDisplays.isEmpty) {
      _fetchDisplays();
    }
  }

  Future<void> _fetchDisplays() async {
    setState(() {
      _isLoading = true;
    });

    await _authService.fetchOsdDisplays();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // If only one display after fetch, auto-select
    if (_authService.availableDisplays.length == 1) {
      _selectDisplay(_authService.availableDisplays.first);
    }
  }

  Future<void> _selectDisplay(DisplayPreset display) async {
    await _authService.selectDisplay(display);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OrderStatusScreen()),
    );
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displays = _authService.availableDisplays;
    final user = _authService.currentUser;

    // Group displays by store
    final Map<String, List<DisplayPreset>> displaysByStore = {};
    for (final display in displays) {
      final storeName = display.storeName ?? 'Unknown Store';
      if (!displaysByStore.containsKey(storeName)) {
        displaysByStore[storeName] = [];
      }
      displaysByStore[storeName]!.add(display);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Select Display'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: OsdElevation.level2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchDisplays,
            tooltip: 'Refresh',
          ),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            )
          : displays.isEmpty
              ? _buildEmptyState()
              : _buildDisplayList(displaysByStore, user),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(OsdSpacing.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_outlined,
              size: OsdLayout.emptyStateIconSmall,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: OsdSpacing.space24),
            const Text(
              'No Displays Available',
              style: TextStyle(
                fontSize: OsdTypography.fontSize20,
                fontWeight: OsdTypography.weightSemibold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: OsdSpacing.space8),
            Text(
              'No OSD displays are configured for your organization.',
              style: TextStyle(
                fontSize: OsdTypography.fontSize14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OsdSpacing.space24),
            ElevatedButton.icon(
              onPressed: _fetchDisplays,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayList(
      Map<String, List<DisplayPreset>> displaysByStore, dynamic user) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(OsdSpacing.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a Display',
                  style: TextStyle(
                    fontSize: OsdTypography.fontSize24,
                    fontWeight: OsdTypography.weightBold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: OsdSpacing.space4),
                Text(
                  'Choose the order status display for this device',
                  style: TextStyle(
                    fontSize: OsdTypography.fontSize14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: OsdSpacing.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OsdSpacing.space12,
                      vertical: OsdSpacing.space6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: OsdRadius.borderRadiusXl,
                    ),
                    child: Text(
                      'Logged in as ${user.email}',
                      style: const TextStyle(
                        fontSize: OsdTypography.fontSize12,
                        color: Color(0xFF2196F3),
                        fontWeight: OsdTypography.weightMedium,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Display list grouped by store
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final storeName = displaysByStore.keys.elementAt(index);
                final storeDisplays = displaysByStore[storeName]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store name header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: OsdSpacing.space12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: OsdIconSizes.size20,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: OsdSpacing.space8),
                          Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: OsdTypography.fontSize16,
                              fontWeight: OsdTypography.weightSemibold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: OsdSpacing.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: OsdSpacing.space8,
                              vertical: OsdSpacing.space2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: OsdRadius.borderRadiusMd,
                            ),
                            child: Text(
                              '${storeDisplays.length}',
                              style: TextStyle(
                                fontSize: OsdTypography.fontSize12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Display cards for this store
                    ...storeDisplays.map((display) => _buildDisplayCard(display)),

                    const SizedBox(height: OsdSpacing.space8),
                  ],
                );
              },
              childCount: displaysByStore.length,
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: OsdSpacing.space24),
        ),
      ],
    );
  }

  Widget _buildDisplayCard(DisplayPreset display) {
    return Card(
      margin: const EdgeInsets.only(bottom: OsdSpacing.space12),
      elevation: OsdElevation.level2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: OsdRadius.borderRadiusMd,
      ),
      child: InkWell(
        onTap: () => _selectDisplay(display),
        borderRadius: OsdRadius.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(OsdSpacing.space16),
          child: Row(
            children: [
              // Display icon
              Container(
                width: OsdLayout.displayIconContainerSize,
                height: OsdLayout.displayIconContainerSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: OsdRadius.borderRadiusMd,
                ),
                child: const Icon(
                  Icons.monitor,
                  color: Colors.white,
                  size: OsdIconSizes.size28,
                ),
              ),

              const SizedBox(width: OsdSpacing.space16),

              // Display info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display name with default badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            display.name,
                            style: const TextStyle(
                              fontSize: OsdTypography.fontSize16,
                              fontWeight: OsdTypography.weightSemibold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        if (display.isDefault) ...[
                          const SizedBox(width: OsdSpacing.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: OsdSpacing.space8,
                              vertical: OsdSpacing.space2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: OsdRadius.borderRadiusSm,
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: OsdTypography.fontSize10,
                                color: Colors.white,
                                fontWeight: OsdTypography.weightSemibold,
                                letterSpacing: OsdTypography.letterSpacing05,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: OsdSpacing.space4),

                    // Categories
                    Row(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: OsdIconSizes.size14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: OsdSpacing.space4),
                        Expanded(
                          child: Text(
                            display.categoryNames,
                            style: TextStyle(
                              fontSize: OsdTypography.fontSize13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Category chips (if not too many)
                    if (display.categories.isNotEmpty &&
                        display.categories.length <= 4) ...[
                      const SizedBox(height: OsdSpacing.space8),
                      Wrap(
                        spacing: OsdSpacing.space6,
                        runSpacing: OsdSpacing.space4,
                        children: display.categories.map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: OsdSpacing.space8,
                              vertical: OsdSpacing.space4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: OsdRadius.borderRadiusXs,
                            ),
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                fontSize: OsdTypography.fontSize11,
                                color: Color(0xFF2196F3),
                                fontWeight: OsdTypography.weightMedium,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
