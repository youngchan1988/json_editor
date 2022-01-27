// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class HighlightConfig {
  HighlightConfig({this.brackets, this.autoClosingPairs, this.keywords});

  final List<Pair>? brackets;
  final List<Pair>? autoClosingPairs;
  final List<String>? keywords;
}

class Pair {
  Pair({this.open, this.close});
  final String? open;
  final String? close;

  @override
  bool operator ==(Object other) =>
      other is Pair && other.open == open && other.close == close;

  @override
  int get hashCode => (open?.isNotEmpty == true && close?.isNotEmpty == true)
      ? (open! + close!).hashCode
      : super.hashCode;
}
