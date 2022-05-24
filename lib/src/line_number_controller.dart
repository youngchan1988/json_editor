import 'package:flutter/material.dart';

class LineNumberController extends TextEditingController {
  LineNumberController(this.lineNumberBuilder);
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool? withComposing,
  }) {
    final children = <TextSpan>[];
    final list = text.split("\n");
    for (int k = 0; k < list.length; k++) {
      final el = list[k];
      final number = int.parse(el);
      var textSpan = TextSpan(text: el, style: style);
      if (lineNumberBuilder != null) {
        textSpan = lineNumberBuilder!(number, style);
      }
      children.add(textSpan);
      if (k < list.length - 1) children.add(const TextSpan(text: "\n"));
    }
    return TextSpan(children: children, style: style);
  }
}

class LineNumberStyle {
  const LineNumberStyle({
    this.width = 42.0,
    this.textAlign = TextAlign.right,
    this.margin = 10.0,
    this.textStyle,
    this.background,
  });

  /// Width of the line number column
  final double width;

  /// Alignment of the numbers in the column
  final TextAlign textAlign;

  /// Style of the numbers
  final TextStyle? textStyle;

  /// Background of the line number column
  final Color? background;

  /// Central horizontal margin between the numbers and the code
  final double margin;
}
