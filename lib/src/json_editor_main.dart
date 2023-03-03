// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_editor/src/analyzer/analyzer.dart';
import 'package:json_editor/src/json_editor_model.dart';
import 'package:json_editor/src/util/logger.dart';
import 'package:json_editor/src/util/undo_redo.dart';

import 'rich_text_field/rich_text_editing_controller.dart';
import 'util/string_util.dart';

class JsonEditor extends StatefulWidget {
  JsonEditor._(
      {Key? key,
      this.jsonString,
      this.jsonObj,
      this.enabled = true,
      this.openDebug = false,
      this.onValueChanged,
      this.onError,
      })
      : assert(jsonObj == null || jsonObj is Map || jsonObj is List),
        super(key: key) {
    initialLogger(openDebug: openDebug);
  }

  factory JsonEditor.string(
          {Key? key,
          String? jsonString,
          bool enabled = true,
          bool openDebug = false,
          ValueChanged<JsonElement?>? onValueChanged,
          ValueChanged<Object>? onError,
          }) =>
      JsonEditor._(
          key: key,
          jsonString: jsonString,
          enabled: enabled,
          openDebug: openDebug,
          onValueChanged: onValueChanged,
          onError: onError,
      );

  factory JsonEditor.object(
          {Key? key,
          Object? object,
          bool enabled = true,
          bool openDebug = false,
          ValueChanged<JsonElement?>? onValueChanged,
          ValueChanged<Object>? onError,
          }) =>
      JsonEditor._(
        key: key,
        jsonObj: object,
        enabled: enabled,
        openDebug: openDebug,
        onValueChanged: onValueChanged,
        onError: onError,
      );

  factory JsonEditor.element(
          {Key? key,
          JsonElement? element,
          bool enabled = true,
          bool openDebug = false,
          ValueChanged<JsonElement?>? onValueChanged,
          ValueChanged<Object>? onError,
          }) =>
      JsonEditor._(
        key: key,
        jsonString: element?.toString(),
        enabled: enabled,
        openDebug: openDebug,
        onValueChanged: onValueChanged,
        onError: onError,
      );

  final String? jsonString;
  final Object? jsonObj;
  final bool enabled;
  final bool openDebug;

  /// Output the decoded json object.
  final ValueChanged<JsonElement?>? onValueChanged;
  final ValueChanged<Object>? onError;

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

  @override
  void initState() {
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
    super.initState();
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
        if (widget.jsonObj == null) {
          _editController.text = "";
        } else {
          _editController.text = jsonEncode(widget.jsonObj);
        }
        _reformat();
        _undoRedo.set(_editController.text);
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
          if (_currentKeyEvent?.logicalKey == LogicalKeyboardKey.enter) {
            // Enter key
            var editingOffset = _editController.selection.baseOffset;
            if (editingOffset == 0) {
              return;
            }
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
          _lastInput = DateTime.now();
          //Analyze json syntax
          _analyze();
          _undoRedoInput(s);
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
          try {
            widget.onError?.call(err);
          } catch (e) {
            hasError = true;
            error(object: this, message: 'analyze error', err: e);
            setState(() {
              _errMessage = e.toString();
            });
          }
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
                const Duration(seconds: 1))) {
      if (_editController.text.isNotEmpty) {
        hasError = _analyzeSync();
      } else {
        widget.onValueChanged?.call(null);
      }
    }
    return Future.value(hasError);
  }

  /// Format code when TextField out of focus.
  void _reformat() {
    if (_editController.text.isEmpty) {
      return;
    }
    _editController.text =
        JsonElement.format(_editController.text, analyzer: _analyzer);
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
