// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'highlight_config.dart';

abstract class HighlightTheme {
  HighlightConfig get config;

  Map<String, TextStyle> get bracketsStyle;

  Map<HighlightDataType, TextStyle> get typeStyle;

  Map<String, TextStyle> get keywordsStyle;

  TextStyle get defaultStyle;
}

enum HighlightDataType { int, double, string, bool, key, comment, error }
