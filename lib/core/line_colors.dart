import 'package:flutter/material.dart';

import 'theme.dart';

const lineColors = <String, Color>{
  'Seremban Line': Color(0xFF4CAF6D),
  'Port Klang Line': Color(0xFF3B82C4),
  'ETS Intercity': Color(0xFFE07A3F),
};

Color lineColor(String line) => lineColors[line] ?? AppColors.neutral;
