import 'package:flutter/material.dart';

import 'colors.dart';

const kStrollWiseLogoAsset = 'lib/app/theme/strollwiselogo.jpg';

class StrollWiseBrandMark extends StatelessWidget {
  const StrollWiseBrandMark({
    super.key,
    this.size = 36,
    this.showWordmark = true,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            kStrollWiseLogoAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.28),
          const Text(
            'StrollWise',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ],
    );
  }
}
