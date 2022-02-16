// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_editor/src/analyzer/analyzer.dart';
import 'package:json_editor/src/json_editor_model.dart';
import 'package:json_editor/src/util/logger.dart';

import 'rich_text_field/rich_text_editing_controller.dart';
import 'util/string_util.dart';

class JsonEditor extends StatefulWidget {
  const JsonEditor._(
      {Key? key,
      this.jsonString,
      this.jsonObj,
      this.enabled = true,
      this.onValueChanged})
      : assert(jsonObj == null || jsonObj is Map || jsonObj is List),
        super(key: key);

  factory JsonEditor.string(
          {Key? key,
          String? jsonString,
          bool enabled = true,
          ValueChanged<JsonElement>? onValueChanged}) =>
      JsonEditor._(
          key: key,
          jsonString: jsonString,
          enabled: enabled,
          onValueChanged: onValueChanged);

  factory JsonEditor.object(
          {Key? key,
          Object? object,
          bool enabled = true,
          ValueChanged<JsonElement>? onValueChanged}) =>
      JsonEditor._(
        key: key,
        jsonObj: object,
        enabled: enabled,
        onValueChanged: onValueChanged,
      );

  factory JsonEditor.element(
          {Key? key,
          JsonElement? element,
          bool enabled = true,
          ValueChanged<JsonElement>? onValueChanged}) =>
      JsonEditor._(
        key: key,
        jsonString: element?.toString(),
        enabled: enabled,
        onValueChanged: onValueChanged,
      );

  final String? jsonString;
  final Object? jsonObj;

  final bool enabled;

  /// Output the decoded json object.
  final ValueChanged<JsonElement>? onValueChanged;

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

  DateTime? _lastInput;

  RawKeyEvent? _currentKeyEvent;

  String? _errMessage;

  @override
  void initState() {
    if (widget.jsonString != null) {
      _editController.text = widget.jsonString!;
      if (!_analyze()) {
        _reformat();
      }
    } else if (widget.jsonObj != null) {
      try {
        _editController.text = jsonEncode(widget.jsonObj);
        if (!_analyze()) {
          _reformat();
        }
      } catch (e) {
        _errMessage = e.toString();
        error(object: this, message: 'initState error', err: e);
      }
    }
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus) {
        _reformat();
      }
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant JsonEditor oldWidget) {
    if (widget.jsonString != oldWidget.jsonString) {
      _editController.text = widget.jsonString!;
      if (!_analyze()) {
        _reformat();
      }
    } else if (widget.jsonObj != oldWidget.jsonObj) {
      try {
        _editController.text = jsonEncode(widget.jsonObj);
        _reformat();
      } catch (e) {
        _errMessage = e.toString();
        error(object: this, message: 'didUpdateWidget error', err: e);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focus,
      onKey: (keyEvent) {
        // debug(object: this, message: 'Key event: ${keyEvent.toString()}');
        if (keyEvent is RawKeyDownEvent) {
          _currentKeyEvent = keyEvent;
        }
      },
      child: TextField(
        readOnly: !widget.enabled,
        focusNode: _editFocus,
        controller: _editController,
        decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            errorText: _errMessage,
            errorMaxLines: 10),
        keyboardType: TextInputType.multiline,
        expands: true,
        maxLines: null,
        minLines: null,
        onChanged: (s) {
          //当前编辑光标输入的字符
          if (_currentKeyEvent?.logicalKey == LogicalKeyboardKey.enter) {
            //回车键处理
            var editingOffset = _editController.selection.baseOffset;
            if (editingOffset == 0) {
              return;
            }
            //当前编辑光标输入的字符
            _enterFormat();
          } else if (_currentKeyEvent?.logicalKey ==
                  LogicalKeyboardKey.braceLeft ||
              _currentKeyEvent?.logicalKey == LogicalKeyboardKey.braceRight) {
            _closingFormat(open: '{', close: '}');
          } else if (_currentKeyEvent?.logicalKey ==
                  LogicalKeyboardKey.bracketLeft ||
              _currentKeyEvent?.logicalKey == LogicalKeyboardKey.bracketRight) {
            _closingFormat(open: '[', close: ']');
          } else if (_currentKeyEvent?.logicalKey == LogicalKeyboardKey.quote) {
            _closingFormat(open: '"', close: '"');
          }
          //Analyze json syntax
          _analyze();
        },
      ),
    );
  }

  void _closingFormat({required String open, required String close}) {
    var s = _editController.text;
    var editingOffset = _editController.selection.baseOffset;
    if (editingOffset == 0) {
      return;
    }
    var editingLastWord = s.characters.elementAt(editingOffset - 1);
    if (editingOffset < s.characters.length && editingOffset - 2 >= 0) {
      if (s.characters.elementAt(editingOffset - 2) != '\\' &&
          editingLastWord == close &&
          s.characters.elementAt(editingOffset) == close) {
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

  ///parse 回车操作
  void _enterFormat() {
    var editingOffset = _editController.selection.baseOffset;
    if (editingOffset < 2) {
      return;
    }
    var s = _editController.text;
    String? editingWord;
    if (editingOffset < s.length) {
      editingWord = s.characters.elementAt(editingOffset);
    }
    var editingLastWord = s.characters.elementAt(editingOffset - 1);
    var lastPreWord = s.characters.elementAt(editingOffset - 2);
    if (editingLastWord == '\n') {
      var p = editingOffset - 2;
      while (p > 0) {
        if (s.characters.elementAt(p) == '\n') {
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

  bool _analyze() {
    _lastInput = DateTime.now();
    _editController.analyzeError = null;
    var hasError = false;
    Future.delayed(const Duration(seconds: 1)).then((value) {
      if (DateTime.now().difference(_lastInput!) >=
              const Duration(seconds: 1) &&
          _editController.text.isNotEmpty) {
        var err = _analyzer.analyze(_editController.text);
        _editController.analyzeError = err;
        if (err == null) {
          setState(() {
            _errMessage = '';
          });
          try {
            var value = JsonElement.fromString(_editController.text);
            widget.onValueChanged?.call(value);
          } catch (e) {
            hasError = true;
            error(object: this, message: 'analyze error', err: e);
            setState(() {
              _errMessage = e.toString();
            });
          }
        } else {
          hasError = true;
          setState(() {
            error(object: this, message: 'analyze error', err: err);
            _errMessage = err.toString();
          });
        }
      }
    });
    return hasError;
  }

  /// 格式化, 在编辑区失焦后执行
  void _reformat() {
    if (_editController.text.isEmpty) {
      return;
    }
    _editController.text =
        JsonElement.format(_editController.text, analyzer: _analyzer);
  }
}
