import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusPill extends StatelessWidget {
  final bool isAvailable;
  final bool isCompact;

  const StatusPill({
    super.key,
    required this.isAvailable,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isAvailable ? AppColors.availableGreenBg : AppColors.busyOrangeBg;
    final dotColor = isAvailable ? AppColors.availableGreen : AppColors.busyOrange;
    final textColor = isAvailable ? const Color(0xFF065F46) : const Color(0xFF9A3412);
    final text = isAvailable ? 'Available Now' : 'Busy';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dotColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: isAvailable
                  ? [
                      BoxShadow(
                        color: dotColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
