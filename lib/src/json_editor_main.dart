// Copyright (c) 2022, the json_editor project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_editor/src/analyzer/analyzer.dart';
import 'package:json_editor/src/analyzer/lexer/lexer.dart';
import 'package:json_editor/src/analyzer/lexer/token.dart';

import 'rich_text_field/rich_text_editing_controller.dart';
import 'util/string_util.dart';

const _indentSpace = '    ';

class JsonEditor extends StatefulWidget {
  const JsonEditor(
      {Key? key,
      this.jsonString,
      this.jsonValue,
      this.enabled = true,
      this.onValue})
      : assert(jsonValue == null || (jsonValue is Map || jsonValue is List)),
        super(key: key);

  /// if [jsonString] and [jsonValue] have both. First to parse jsonString.
  final String? jsonString;

  /// if [jsonString] and [jsonValue] have both. First to parse jsonString.
  /// [jsonValue] must be a Map or a List.
  final Object? jsonValue;

  final bool enabled;

  /// Output the decoded json object.
  final ValueChanged<Object>? onValue;

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
      _reformat();
    } else if (widget.jsonValue != null) {
      _editController.text = _formatJsonValue(widget.jsonValue!);
      _reformat();
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
    if (!widget.enabled) {
      if (widget.jsonString != null) {
        _editController.text = widget.jsonString!;
        _reformat();
      } else if (widget.jsonValue != null) {
        _editController.text = _formatJsonValue(widget.jsonValue!);
        _reformat();
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
            border: InputBorder.none, isDense: true, errorText: _errMessage),
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
        _analyze();
        return;
      }
    }
    if (editingLastWord == open) {
      _editController.text = s.insertStringAt(editingOffset, close);
      _editController.selection =
          TextSelection.fromPosition(TextPosition(offset: editingOffset));
      _analyze();
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
      while (sub.indexOf(_indentSpace) == 0) {
        sub = sub.substring(4);
        indent += _indentSpace;
      }
      if (indent.isNotEmpty) {
        _editController.text = s.insertStringAt(editingOffset, indent);
        _editController.selection = TextSelection.fromPosition(
            TextPosition(offset: editingOffset + indent.length));
      }
      if (lastPreWord == '{' || lastPreWord == '[') {
        //缩进
        var newIndent = indent + _indentSpace;
        if (editingWord == '}' || editingWord == ']') {
          newIndent += '\n' + indent;
        }
        _editController.text = s.insertStringAt(editingOffset, newIndent);
        _editController.selection = TextSelection.fromPosition(
            TextPosition(offset: editingOffset + indent.length + 4));
      }
    }
  }

  String _formatJsonValue(Object jsonValue) {
    var jsonString = '';
    try {
      jsonString = jsonEncode(jsonValue);
    } catch (e) {
      _errMessage = e.toString();
    }
    return jsonString;
  }

  void _analyze() {
    _lastInput = DateTime.now();
    _editController.analyzeError = null;
    Future.delayed(const Duration(seconds: 1)).then((value) {
      if (DateTime.now().difference(_lastInput!) >=
              const Duration(seconds: 1) &&
          _editController.text.isNotEmpty) {
        var error = _analyzer.analyze(_editController.text);
        _editController.analyzeError = error;
        if (error == null) {
          setState(() {
            _errMessage = '';
          });
          try {
            var value = _decodeJsonValue(_editController.text);
            widget.onValue?.call(value);
          } catch (e) {
            setState(() {
              _errMessage = e.toString();
            });
          }
        } else {
          setState(() {
            _errMessage = error.toString();
          });
        }
        // try {
        //   var m = jsonDecode(_editController.text);
        //   widget.onValue?.call(m);
        //   setState(() {
        //     _errMessage = '';
        //   });
        // } catch (error) {
        //   setState(() {
        //     _errMessage = error.toString();
        //   });
        // }
      }
    });
  }

  /// 格式化, 在编辑区失焦后执行
  void _reformat() {
    if (_editController.text.isEmpty) {
      return;
    }
    var error = _analyzer.analyze(_editController.text);
    if (error == null) {
      var tokens = Lexer().scan(_editController.text);
      var reformatText = '';
      var lastLineIndentNumber = 0;
      while (!tokens.isEof) {
        if (tokens.precedingComments != null) {
          var commentText =
              '${tokens.precedingComments!.toString()}\n${_createIndentSpace(lastLineIndentNumber)}';
          var nextComment = tokens.precedingComments?.next;
          while (nextComment is CommentToken) {
            commentText +=
                '${nextComment.toString()}\n${_createIndentSpace(lastLineIndentNumber)}';
            nextComment = nextComment.next;
          }
          reformatText += commentText;
        }
        reformatText += tokens.lexeme;
        if (tokens.lexeme == '{' || tokens.lexeme == '[') {
          lastLineIndentNumber++;
          reformatText += '\n${_createIndentSpace(lastLineIndentNumber)}';
        } else if (tokens.lexeme == ':') {
          reformatText += '  ';
        }
        if (tokens.next?.lexeme == '}' ||
            tokens.next?.lexeme == ']' ||
            tokens.next?.isEof == true) {
          lastLineIndentNumber =
              lastLineIndentNumber > 0 ? --lastLineIndentNumber : 0;
          reformatText += '\n${_createIndentSpace(lastLineIndentNumber)}';
        } else if (tokens.lexeme == ',') {
          reformatText += '\n${_createIndentSpace(lastLineIndentNumber)}';
        }

        tokens = tokens.next!;
      }
      _editController.text = reformatText;
    }
  }

  String _createIndentSpace(int number) {
    var indent = '';
    for (var i = 0; i < number; i++) {
      indent += _indentSpace;
    }
    return indent;
  }

  dynamic _decodeJsonValue(String input) {
    var tokens = Lexer().scan(input);
    var jsonText = '';
    while (!tokens.isEof) {
      jsonText += tokens.lexeme;
      tokens = tokens.next!;
    }
    return jsonDecode(jsonText);
  }
}
