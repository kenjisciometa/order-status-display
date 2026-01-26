import 'dart:async';
import 'package:flutter/material.dart';
import '../models/osd_order.dart';

/// Order Card Widget
///
/// Displays a single order with its call number prominently.
/// Includes flashing animation for orders that have been waiting too long.
class OrderCard extends StatefulWidget {
  final OsdOrder order;
  final bool isReady;

  const OrderCard({
    super.key,
    required this.order,
    this.isReady = false,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();

    // Setup flash animation
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flashAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    // Start flashing if needed
    if (widget.order.shouldFlash) {
      _flashController.repeat(reverse: true);
    }

    // Update timer for elapsed time
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
        // Update flash state
        if (widget.order.shouldFlash && !_flashController.isAnimating) {
          _flashController.repeat(reverse: true);
        }
      }
    });
  }

  @override
  void didUpdateWidget(OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update flash animation if order changed
    if (widget.order.shouldFlash && !_flashController.isAnimating) {
      _flashController.repeat(reverse: true);
    } else if (!widget.order.shouldFlash && _flashController.isAnimating) {
      _flashController.stop();
      _flashController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final priorityColor = order.priorityColor;

    return AnimatedBuilder(
      animation: _flashAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: widget.order.shouldFlash ? _flashAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.isReady
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF1E3A5F),
                  widget.isReady
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF2A4A6F),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isReady
                    ? const Color(0xFF4CAF50)
                    : priorityColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isReady
                          ? const Color(0xFF4CAF50)
                          : priorityColor)
                      .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label (if any)
                if (order.displayLabel.isNotEmpty)
                  Text(
                    order.displayLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),

                // Call Number (main display)
                Text(
                  order.displayNumber,
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                // Elapsed time indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatElapsedTime(widget.isReady
                        ? order.elapsedSinceReady
                        : order.elapsedTime),
                    style: TextStyle(
                      fontSize: 14,
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Dining option (if available)
                if (order.diningOption != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatDiningOption(order.diningOption!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatElapsedTime(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return 'Now';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  String _formatDiningOption(String option) {
    switch (option.toLowerCase()) {
      case 'dine_in':
      case 'dine-in':
      case 'dinein':
        return 'Dine-in';
      case 'take_out':
      case 'take-out':
      case 'takeout':
        return 'Takeout';
      case 'delivery':
        return 'Delivery';
      default:
        return option;
    }
  }
}
