import 'dart:async';
import 'package:flutter/material.dart';
import '../models/osd_order.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_layout.dart';

/// Order Card Widget
///
/// Displays a single order with its call number prominently.
/// Includes flashing animation for orders that have been waiting too long.
/// Uses FittedBox to auto-scale text and prevent overflow.
/// Supports highlighted mode for recently ready orders.
class OrderCard extends StatefulWidget {
  final OsdOrder order;
  final bool isReady;
  final bool isDarkMode;
  final bool isHighlighted; // For recently ready orders - larger, more prominent
  final bool showElapsedTime; // Whether to show elapsed time (for Now Cooking)

  const OrderCard({
    super.key,
    required this.order,
    this.isReady = false,
    this.isDarkMode = true,
    this.isHighlighted = false,
    this.showElapsedTime = true, // Default true for It's Ready, controlled for Now Cooking
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();

    // Setup pulse animation (for highlighted/recently ready orders)
    _pulseController = AnimationController(
      duration: OsdDurations.pulse,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: OsdAnimations.pulseScaleStart,
      end: OsdAnimations.pulseScaleEnd,
    ).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulse animation for highlighted orders
    if (widget.isHighlighted) {
      _pulseController.repeat(reverse: true);
    }

    // Update timer for elapsed time display
    _updateTimer = Timer.periodic(OsdDurations.cardUpdateInterval, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update pulse animation for highlighted state
    if (widget.isHighlighted && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isHighlighted && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final priorityColor = order.priorityColor;
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
    final isHighlighted = widget.isHighlighted;

    // Background colors based on theme, status, and highlight
    final List<Color> gradientColors;
    if (isHighlighted) {
      // Highlighted (recently ready) - Vibrant green with glow effect
      gradientColors = isDarkMode
          ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
          : [const Color(0xFF81C784), const Color(0xFFA5D6A7)];
    } else if (widget.isReady) {
      gradientColors = isDarkMode
          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
          : [const Color(0xFFA5D6A7), const Color(0xFFC8E6C9)];
    } else {
      gradientColors = isDarkMode
          ? [const Color(0xFF1E3A5F), const Color(0xFF2A4A6F)]
          : [const Color(0xFFBBDEFB), const Color(0xFFE3F2FD)];
    }

    // Border color and width
    // Now Cooking: Always orange border
    // It's Ready: Green border (or highlighted green)
    const orangeColor = Color(0xFFFF9800); // Orange for Now Cooking
    final borderColor = isHighlighted
        ? const Color(0xFF4CAF50)
        : widget.isReady
            ? const Color(0xFF4CAF50)
            : orangeColor.withOpacity(isDarkMode ? 0.7 : 0.8);
    final borderWidth = isHighlighted
        ? OsdLayout.cardHighlightedBorderWidth
        : OsdLayout.cardBorderWidth;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isHighlighted ? _pulseAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isHighlighted ? OsdLayout.cardHighlightedPaddingH : OsdLayout.cardPaddingH,
              vertical: isHighlighted ? OsdLayout.cardHighlightedPaddingV : OsdLayout.cardPaddingV,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(
                isHighlighted ? OsdRadius.lg : OsdRadius.md,
              ),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isHighlighted
                          ? const Color(0xFF4CAF50)
                          : widget.isReady
                              ? const Color(0xFF4CAF50)
                              : orangeColor)
                      .withOpacity(isHighlighted ? 0.6 : (isDarkMode ? 0.3 : 0.2)),
                  blurRadius: isHighlighted ? 16 : 8,
                  spreadRadius: isHighlighted ? 2 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isHighlighted
                ? _buildHighlightedContent(order, textColor)
                : _buildNormalContent(order, textColor, priorityColor, isDarkMode, widget.showElapsedTime),
          ),
        );
      },
    );
  }

  /// Build content for highlighted (recently ready) cards - Centered, large number
  Widget _buildHighlightedContent(OsdOrder order, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Large call number - centered
        Expanded(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OsdSpacing.space8),
              child: Text(
                order.displayNumber,
                style: TextStyle(
                  fontWeight: OsdTypography.weightBold,
                  color: textColor,
                  letterSpacing: OsdTypography.letterSpacing2,
                ),
              ),
            ),
          ),
        ),
        // "Ready!" label at bottom
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OsdSpacing.space12,
            vertical: OsdSpacing.space4,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: OsdRadius.borderRadiusMd,
          ),
          child: Text(
            'READY!',
            style: TextStyle(
              fontSize: OsdTypography.fontSize14,
              fontWeight: OsdTypography.weightBold,
              color: textColor,
              letterSpacing: OsdTypography.letterSpacing1,
            ),
          ),
        ),
      ],
    );
  }

  /// Build content for normal cards - Horizontal layout
  Widget _buildNormalContent(OsdOrder order, Color textColor, Color priorityColor, bool isDarkMode, bool showElapsedTime) {
    // If not showing elapsed time, just show centered number only
    if (!showElapsedTime) {
      // Simple centered number only - no other content
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            order.displayNumber,
            style: TextStyle(
              fontSize: OsdTypography.fontSize48,
              fontWeight: OsdTypography.weightBold,
              color: textColor,
              letterSpacing: OsdTypography.letterSpacing1,
            ),
          ),
        ),
      );
    }

    // showElapsedTime is true - show full layout with elapsed time and optional dining option
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Call Number (main display) - Auto-scaled, takes most space
        Expanded(
          flex: OsdLayout.cardCallNumberFlex,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              order.displayNumber,
              style: TextStyle(
                fontSize: OsdTypography.fontSize48,
                fontWeight: OsdTypography.weightBold,
                color: textColor,
                letterSpacing: OsdTypography.letterSpacing1,
              ),
            ),
          ),
        ),

        const SizedBox(width: OsdSpacing.space8),

        // Right side info: elapsed time and dining option
        Expanded(
          flex: OsdLayout.cardElapsedTimeFlex,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Elapsed time indicator
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OsdSpacing.space8,
                    vertical: OsdSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                    borderRadius: OsdRadius.borderRadiusBase,
                  ),
                  child: Text(
                    _formatElapsedTime(widget.isReady
                        ? order.elapsedSinceReady
                        : order.elapsedTime),
                    style: TextStyle(
                      fontSize: OsdTypography.fontSize12,
                      color: priorityColor,
                      fontWeight: OsdTypography.weightMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatElapsedTime(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '<1m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }
}
