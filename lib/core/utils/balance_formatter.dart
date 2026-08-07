import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BalanceInfo {
  final String text;
  final String amount;
  final Color color;
  final bool isZero;

  BalanceInfo({
    required this.text,
    required this.amount,
    required this.color,
    required this.isZero,
  });
}

class BalanceFormatter {
  static BalanceInfo format(double balance, {int decimals = 3}) {
    if (balance > 0.001) {
      return BalanceInfo(
        text: 'مدين (باقي عليه)',
        amount: balance.toStringAsFixed(decimals),
        color: AppTheme.danger,
        isZero: false,
      );
    } else if (balance < -0.001) {
      return BalanceInfo(
        text: 'دائن (باقي له)',
        amount: balance.abs().toStringAsFixed(decimals),
        color: AppTheme.success,
        isZero: false,
      );
    } else {
      return BalanceInfo(
        text: 'مسوّى ✓',
        amount: '0.${'0' * decimals}',
        color: AppTheme.textSecondary,
        isZero: true,
      );
    }
  }
}
