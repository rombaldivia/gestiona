import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GestionaLogoMark extends StatelessWidget {
  const GestionaLogoMark({
    super.key,
    this.size = 40,
    this.withBackground = false,
    this.backgroundColor,
    this.padding,
  });

  final double size;
  final bool withBackground;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/brand/gestiona_logo_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (!withBackground) return logo;

    return Container(
      width: size,
      height: size,
      padding: padding ?? EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: AppShadows.elevated,
      ),
      child: logo,
    );
  }
}

class GestionaLogoLockup extends StatelessWidget {
  const GestionaLogoLockup({
    super.key,
    this.logoSize = 72,
    this.showTagline = true,
    this.center = true,
  });

  final double logoSize;
  final bool showTagline;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final children = [
      GestionaLogoMark(size: logoSize, withBackground: true),
      const SizedBox(height: 20),
      Text(
        'Gestiona',
        style: AppTextStyles.display.copyWith(
          color: AppColors.primary,
          letterSpacing: -1,
        ),
      ),
      if (showTagline) ...[
        const SizedBox(height: 6),
        Text('Tu empresa, bajo control', style: AppTextStyles.body),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: children,
    );
  }
}
