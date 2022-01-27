// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'rich_text_field/highlight_theme/json_theme.dart';

class JsonEditorTheme extends InheritedWidget {
  const JsonEditorTheme(
      {Key? key, required this.themeData, required Widget child})
      : super(key: key, child: child);

  final JsonEditorThemeData themeData;
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;

  static JsonEditorThemeData? of(BuildContext context) =>
      context.findAncestorWidgetOfExactType<JsonEditorTheme>()?.themeData;
}

class JsonEditorThemeData {
  JsonEditorThemeData({required this.lightTheme, this.darkTheme});

  factory JsonEditorThemeData.defaultTheme() => JsonEditorThemeData(
      lightTheme: JsonTheme(
          defaultStyle:
              TextStyle(color: Colors.blueGrey.shade900, fontSize: 14),
          bracketStyle:
              TextStyle(color: Colors.blueGrey.shade900, fontSize: 14),
          numberStyle: TextStyle(color: Colors.blue.shade500, fontSize: 14),
          stringStyle: TextStyle(color: Colors.green.shade800, fontSize: 14),
          boolStyle: TextStyle(color: Colors.orange.shade800, fontSize: 14),
          keyStyle: TextStyle(color: Colors.blueGrey.shade600, fontSize: 14),
          commentStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          errorStyle: TextStyle(
              color: Colors.red.shade600,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline)),
      darkTheme: JsonTheme(
          defaultStyle: TextStyle(color: Colors.white, fontSize: 14),
          bracketStyle: TextStyle(color: Colors.white70, fontSize: 14),
          numberStyle: TextStyle(color: Colors.blue.shade500, fontSize: 14),
          stringStyle: TextStyle(color: Colors.green.shade800, fontSize: 14),
          boolStyle: TextStyle(color: Colors.orange.shade800, fontSize: 14),
          keyStyle: TextStyle(color: Colors.blueGrey.shade200, fontSize: 14),
          commentStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          errorStyle: TextStyle(
              color: Colors.red.shade600,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline)));

  final JsonTheme lightTheme;
  final JsonTheme? darkTheme;

  JsonTheme theme(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return darkTheme ?? lightTheme;
    } else {
      return lightTheme;
    }
  }
}
