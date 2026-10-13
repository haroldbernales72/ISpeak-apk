import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ISpeakLogo extends StatelessWidget {
  final double iconSize;
  final double textSize;
  final bool showSubtitle;

  const ISpeakLogo({
    super.key,
    this.iconSize = 60,
    this.textSize = 30,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.campaign_rounded,
            color: AppColors.umBlue,
            size: iconSize * 0.55,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'ISpeak',
          style: TextStyle(
            color: AppColors.white,
            fontSize: textSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),

        if (showSubtitle) ...[
          const SizedBox(height: 4),

          const Text(
            'UM School Safety & Incident Reporting',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}