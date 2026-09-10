import 'package:flutter/material.dart';

import 'theme.dart';

const lineColors = <String, Color>{
  'Seremban Line': Color(0xFF34774A),
  'Port Klang Line': Color(0xFF326EA7),
  'ETS': Color(0xFFA1582D),
  'Ipoh Line': Color(0xFF8B4CC2),
  'Padang Besar Line': Color(0xFF0B767E),
  'ERT': Color(0xFFB83A6D),
  'SH': Color(0xFFB02F3A),
  'ST': Color(0xFF5161CB),
  'Shuttle Selatan': Color(0xFF5E7322),
};

Color lineColor(String line) => lineColors[line] ?? AppColors.neutral;
