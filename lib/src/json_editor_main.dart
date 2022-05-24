// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_editor/json_editor.dart';
import 'package:json_editor/src/analyzer/analyzer.dart';
import 'package:json_editor/src/line_number_controller.dart';
import 'package:json_editor/src/util/logger.dart';
import 'package:json_editor/src/util/undo_redo.dart';

import 'rich_text_field/rich_text_editing_controller.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'util/string_util.dart';

class JsonEditor extends StatefulWidget {
  JsonEditor._({
    Key? key,
    this.jsonString,
    this.initialString,
    this.jsonObj,
    this.enabled = true,
    this.openDebug = false,
    this.onValueChanged,
    this.onRawValueChanged,
    this.lineNumberStyle = const LineNumberStyle(),
    this.lineNumberBuilder,
  })  : assert(jsonObj == null || jsonObj is Map || jsonObj is List),
        super(key: key) {
    initialLogger(openDebug: openDebug);
  }

  factory JsonEditor.string({
    Key? key,
    String? jsonString,
    String? initialString,
    bool enabled = true,
    bool openDebug = false,
    ValueChanged<JsonElement>? onValueChanged,
    ValueChanged<String>? onRawValueChanged,
    LineNumberStyle lineNumberStyle = const LineNumberStyle(),
    TextSpan Function(int, TextStyle?)? lineNumberBuilder,
  }) =>
      JsonEditor._(
        key: key,
        jsonString: jsonString,
        initialString: initialString,
        enabled: enabled,
        openDebug: openDebug,
        onValueChanged: onValueChanged,
        onRawValueChanged: onRawValueChanged,
        lineNumberBuilder: lineNumberBuilder,
        lineNumberStyle: lineNumberStyle,
      );

  factory JsonEditor.object({
    Key? key,
    Object? object,
    bool enabled = true,
    bool openDebug = false,
    ValueChanged<JsonElement>? onValueChanged,
    ValueChanged<String>? onRawValueChanged,
    LineNumberStyle lineNumberStyle = const LineNumberStyle(),
    TextSpan Function(int, TextStyle?)? lineNumberBuilder,
  }) =>
      JsonEditor._(
        key: key,
        jsonObj: object,
        enabled: enabled,
        openDebug: openDebug,
        onValueChanged: onValueChanged,
        onRawValueChanged: onRawValueChanged,
        lineNumberBuilder: lineNumberBuilder,
        lineNumberStyle: lineNumberStyle,
      );

  factory JsonEditor.element({
    Key? key,
    JsonElement? element,
    bool enabled = true,
    bool openDebug = false,
    ValueChanged<JsonElement>? onValueChanged,
    ValueChanged<String>? onRawValueChanged,
    LineNumberStyle lineNumberStyle = const LineNumberStyle(),
    TextSpan Function(int, TextStyle?)? lineNumberBuilder,
  }) =>
      JsonEditor._(
        key: key,
        jsonString: element?.toString(),
        enabled: enabled,
        openDebug: openDebug,
        onValueChanged: onValueChanged,
        onRawValueChanged: onRawValueChanged,
        lineNumberBuilder: lineNumberBuilder,
        lineNumberStyle: lineNumberStyle,
      );

  final String? jsonString;
  final String? initialString;
  final Object? jsonObj;
  final bool enabled;
  final bool openDebug;

  /// Output the decoded json object.
  final ValueChanged<JsonElement>? onValueChanged;

  /// Output the raw String.
  final ValueChanged<String>? onRawValueChanged;

  /// A LineNumberStyle instance to tweak the line number column styling
  final LineNumberStyle lineNumberStyle;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  static Map<String, JsonElement> _fromValue(Map map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key, JsonElement(value: _fromValue(value)));
      } else if (value is List) {
        return MapEntry(key, JsonElement(value: _fromValueList(value)));
      } else if (value is JsonElement) {
        return MapEntry(key, value);
      } else {
        return MapEntry(key, JsonElement(value: value));
      }
    });
  }

  static List _fromValueList(List list) {
    var result = [];
    for (var v in list) {
      if (v is Map) {
        result.add(JsonElement(value: _fromValue(v)));
      } else if (v is List) {
        result.add(JsonElement(value: _fromValueList(v)));
      } else if (v is JsonElement) {
        result.add(v);
      } else {
        result.add(JsonElement(value: v));
      }
    }
    return result;
  }

  @override
  _JsonEditorState createState() => _JsonEditorState();
}

class _JsonEditorState extends State<JsonEditor> {
  final _editController = RichTextEditingController();
  final _focus = FocusNode();
  final _editFocus = FocusNode();
  final _analyzer = JsonAnalyzer();
  final _undoRedo = UndoRedo();

  DateTime? _lastInput;

  RawKeyEvent? _currentKeyEvent;

  String? _errMessage;

  late LineNumberController? _numberController;

  String? lines;
  String longestLine = "";

  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  LinkedScrollControllerGroup? _controllers;

  @override
  void initState() {
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _numberController = LineNumberController(widget.lineNumberBuilder);
    _editController.addListener(_onTextChanged);
    if (widget.initialString != null) {
      _editController.text = widget.initialString!;
      if (!_analyzeSync()) {
        _reformat();
      }
      _undoRedo.set(_editController.text);
    }
    if (widget.jsonString != null) {
      _editController.text = widget.jsonString!;
      if (!_analyzeSync()) {
        _reformat();
      }
      _undoRedo.set(_editController.text);
    } else if (widget.jsonObj != null) {
      try {
        _editController.text = jsonEncode(widget.jsonObj);
        if (!_analyzeSync()) {
          _reformat();
        }
        _undoRedo.set(_editController.text);
      } catch (e) {
        _errMessage = e.toString();
        error(object: this, message: 'initState error', err: e);
      }
    }
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus) {
        _reformat();
        _undoRedo.input(_editController.text);
      }
    });
    _onTextChanged();
    super.initState();
  }

  @override
  void dispose() {
    _editController.removeListener(_onTextChanged);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _numberController?.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JsonEditor oldWidget) {
    if (widget.jsonString != oldWidget.jsonString) {
      _editController.text = widget.jsonString!;
      if (!_analyzeSync()) {
        _reformat();
      }
      _undoRedo.set(_editController.text);
    } else if (widget.jsonObj != oldWidget.jsonObj) {
      try {
        _editController.text = jsonEncode(widget.jsonObj);
        _reformat();
        _undoRedo.set(_editController.text);
      } catch (e) {
        _errMessage = e.toString();
        error(object: this, message: 'didUpdateWidget error', err: e);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = _editController.text.split("\n");
    final buf = <String>[];
    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }
    _numberController?.text = buf.join("\n");
    // Find longest line
    longestLine = "";
    _editController.text.split("\n").forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });
    setState(() {});
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView({
    required Widget child,
    required TextStyle textStyle,
    required double minWidth,
  }) {
    final leftPad = widget.lineNumberStyle.margin / 2;
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0.0,
              minWidth: max(minWidth - leftPad, 0.0),
            ),
            child: Padding(
              child: Text(longestLine, style: textStyle),
              padding: const EdgeInsets.only(right: 16.0),
            ), // Add extra padding
          ),
          Expanded(child: child),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: leftPad),
      scrollDirection: Axis.horizontal,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    TextStyle numberTextStyle =
        widget.lineNumberStyle.textStyle ?? const TextStyle();

    TextStyle textStyle = numberTextStyle;

    textStyle = textStyle.copyWith(
      fontSize: 14.0,
    );
    final numberColor = Colors.blueGrey.shade900;
    // Copy important attributes
    numberTextStyle = numberTextStyle.copyWith(
      color: numberTextStyle.color ?? numberColor,
      fontSize: textStyle.fontSize,
      fontFamily: textStyle.fontFamily,
      height: 1.5,
    );
    final lineNumberCol = TextField(
      style: numberTextStyle,
      controller: _numberController,
      enabled: false,
      expands: true,
      maxLines: null,
      minLines: null,
      scrollController: _numberScroll,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        errorText: _errMessage,
        errorMaxLines: 10,
      ),
      textAlign: widget.lineNumberStyle.textAlign,
    );

    final numberCol = Container(
      width: widget.lineNumberStyle.width,
      padding: EdgeInsets.only(right: widget.lineNumberStyle.margin / 2),
      color: widget.lineNumberStyle.background,
      child: lineNumberCol,
    );

    return RawKeyboardListener(
      focusNode: _focus,
      onKey: (keyEvent) {
        // debug(object: this, message: 'Key event: ${keyEvent.toString()}');
        if (keyEvent is RawKeyDownEvent) {
          if (keyEvent.isAltPressed &&
              keyEvent.isShiftPressed &&
              keyEvent.logicalKey.keyLabel ==
                  LogicalKeyboardKey.keyF.keyLabel) {
            _reformat();
          }
          _currentKeyEvent = keyEvent;
          if (keyEvent.isControlPressed &&
              keyEvent.logicalKey == LogicalKeyboardKey.keyZ) {
            if (keyEvent.isShiftPressed) {
              //Redo

              var s = _undoRedo.redo();
              debug(tag: 'UndoRedo', message: 'Redo=>\n$s');
              if (s != null) {
                _editController.text = s;
              }
            } else {
              //Undo

              var s = _undoRedo.undo();
              debug(tag: 'UndoRedo', message: 'Undo=>\n$s');
              if (s != null) {
                _editController.text = s;
              }
            }
          }
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          numberCol,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _wrapInScrollView(
                minWidth: constraints.maxWidth,
                textStyle: textStyle,
                child: TextField(
                  readOnly: !widget.enabled,
                  scrollController: _codeScroll,
                  focusNode: _editFocus,
                  controller: _editController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    errorText: _errMessage,
                    errorMaxLines: 10,
                  ),
                  keyboardType: TextInputType.multiline,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  onChanged: (s) {
                    widget.onRawValueChanged?.call(s);
                    if (_currentKeyEvent?.logicalKey ==
                        LogicalKeyboardKey.enter) {
                      // Enter key
                      var editingOffset = _editController.selection.baseOffset;
                      if (editingOffset == 0) {
                        return;
                      }
                      _enterFormat();
                    } else if (_currentKeyEvent?.logicalKey ==
                            LogicalKeyboardKey.braceLeft ||
                        _currentKeyEvent?.logicalKey ==
                            LogicalKeyboardKey.braceRight) {
                      _closingFormat(open: '{', close: '}');
                    } else if (_currentKeyEvent?.logicalKey ==
                            LogicalKeyboardKey.bracketLeft ||
                        _currentKeyEvent?.logicalKey ==
                            LogicalKeyboardKey.bracketRight) {
                      _closingFormat(open: '[', close: ']');
                    } else if (_currentKeyEvent?.logicalKey ==
                        LogicalKeyboardKey.quote) {
                      _closingFormat(open: '"', close: '"');
                    }
                    _lastInput = DateTime.now();
                    //Analyze json syntax
                    _analyze();
                    _undoRedoInput(s);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closingFormat({required String open, required String close}) {
    var s = _editController.text;
    var editingOffset = _editController.selection.baseOffset;
    if (editingOffset == 0) {
      return;
    }
    var editingLastWord = s.substring(editingOffset - 1, editingOffset);
    if (editingOffset < s.length && editingOffset - 2 >= 0) {
      if (s.substring(editingOffset - 2, editingOffset - 1) != '\\' &&
          editingLastWord == close &&
          s.substring(editingOffset, editingOffset + 1) == close) {
        _editController.text = s.removeCharAt(editingOffset);
        _editController.selection =
            TextSelection.fromPosition(TextPosition(offset: editingOffset));
        return;
      }
    }
    if (editingLastWord == open) {
      _editController.text = s.insertStringAt(editingOffset, close);
      _editController.selection =
          TextSelection.fromPosition(TextPosition(offset: editingOffset));
    }
  }

  ///Parse enter
  void _enterFormat() {
    var editingOffset = _editController.selection.baseOffset;
    if (editingOffset < 2) {
      return;
    }
    var s = _editController.text;
    String? editingWord;
    if (editingOffset < s.length) {
      editingWord = s.substring(editingOffset, editingOffset + 1);
    }
    var editingLastWord = s.substring(editingOffset - 1, editingOffset);
    var lastPreWord = s.substring(editingOffset - 2, editingOffset - 1);
    if (editingLastWord == '\n') {
      var p = editingOffset - 2;
      while (p > 0) {
        if (s.substring(p, p + 1) == '\n') {
          p++;
          break;
        }
        p--;
      }

      var sub = s.substring(p, editingOffset - 1);
      var indent = '';
      while (sub.indexOf(jsonFormatIndent) == 0) {
        sub = sub.substring(4);
        indent += jsonFormatIndent;
      }
      if (indent.isNotEmpty) {
        _editController.text = s.insertStringAt(editingOffset, indent);
        _editController.selection = TextSelection.fromPosition(
            TextPosition(offset: editingOffset + indent.length));
      }
      if (lastPreWord == '{' || lastPreWord == '[') {
        //缩进
        var newIndent = indent + jsonFormatIndent;
        if (editingWord == '}' || editingWord == ']') {
          newIndent += '\n' + indent;
        }
        _editController.text = s.insertStringAt(editingOffset, newIndent);
        _editController.selection = TextSelection.fromPosition(
            TextPosition(offset: editingOffset + indent.length + 4));
      }
    }
  }

  bool _analyzeSync() {
    var hasError = false;
    var text = _editController.text;
    if (text.isNotEmpty) {
      var err = _analyzer.analyze(text);
      _editController.analyzeError = err;
      if (mounted) {
        if (err == null) {
          setState(() {
            _errMessage = '';
          });
          try {
            var value = JsonElement.fromString(text);
            widget.onValueChanged?.call(value);
          } catch (e) {
            hasError = true;
            error(object: this, message: 'analyze error', err: e);
            setState(() {
              _errMessage = e.toString();
            });
          }
        } else {
          setState(() {
            error(object: this, message: 'analyze error', err: err);
            _errMessage = err.toString();
          });
        }
      }
    }
    return hasError;
  }

  Future<bool> _analyze() async {
    _editController.analyzeError = null;
    var hasError = false;
    //Wait for input complete
    await Future.delayed(const Duration(seconds: 1));
    if ((_lastInput == null ||
            DateTime.now().difference(_lastInput!) >=
                const Duration(seconds: 1)) &&
        _editController.text.isNotEmpty) {
      try {
        hasError = _analyzeSync();
      } on Exception catch (error) {
        if (kDebugMode) {
          print(error);
        }
        return true;
      }
    }
    return Future.value(hasError);
  }

  /// Format code when TextField out of focus.
  void _reformat() {
    if (_editController.text.isEmpty) {
      return;
    }
    final selection = _editController.selection;
    _editController.text =
        JsonElement.format(_editController.text, analyzer: _analyzer);
    _editController.selection = selection;
  }

  void _undoRedoInput(String s) {
    if (_currentKeyEvent?.logicalKey == LogicalKeyboardKey.enter ||
        _currentKeyEvent?.logicalKey == LogicalKeyboardKey.space) {
      _undoRedo.input(s);
    } else {
      Future.delayed(const Duration(seconds: 1)).then((value) {
        if (DateTime.now().difference(_lastInput!) >=
                const Duration(seconds: 1) &&
            _editController.text != _undoRedo.current) {
          _undoRedo.input(s);
        }
      });
    }
  }
}
