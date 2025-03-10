import 'package:flutter/material.dart';

class AppTheme {
  final Color appBarColor;
  final Color primaryColor;
  final Color focusColor;
  final Color shimmerBaseColor;
  final Color shimmerHighlightColor;

  AppTheme({
    this.appBarColor = Colors.white,
    this.primaryColor = Colors.white,
    this.focusColor = Colors.white,
    this.shimmerBaseColor = const Color.fromARGB(255, 185, 185, 185),
    this.shimmerHighlightColor = const Color.fromARGB(255, 209, 209, 209),
  });
}
