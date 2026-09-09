import 'package:flutter/material.dart';

/// Screen padding that keeps content above Android gesture/nav bars.
EdgeInsets screenPadding(
  BuildContext context, {
  double horizontal = 20,
  double top = 0,
  double bottom = 20,
}) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom + safeBottom);
}
