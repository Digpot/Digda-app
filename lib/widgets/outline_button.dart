import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color textColor;
  final double height;

  const AppOutlineButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor = AppColors.primary,
    this.textColor = AppColors.primary,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 345,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            height: 1.21,
            letterSpacing: 0,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
