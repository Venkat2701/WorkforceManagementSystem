import 'package:flutter/material.dart';

class AppColors {
  // Saffron Theme Colors
  static const Color primary = Color(0xFFFF9933);
  static const Color primaryDark = Color(0xFFCC7A29);
  static const Color primaryLight = Color(0xFFFFB366);
  
  // Neutral Colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundAlt = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textHigh = Color(0xFF181410);
  static const Color textMedium = Color(0xFF8D755E);
  static const Color textLow = Color(0xFFB8A696);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF2196F3);
}

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double circular = 9999.0;
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withOpacity(0.05),
      blurRadius: 1,
      spreadRadius: 0,
    ),
  ];
}
