import 'package:flutter_test/flutter_test.dart';
import 'package:json_editor/src/analyzer/analyzer.dart';
import 'package:json_editor/src/analyzer/lexer/lexer.dart';

void main() {
  group('Lexer', () {
    test('Tokens', () {
      var tokens = Lexer().scan(
          '{"name": "you", "age": 23, "child": true, "obj": { "serialNo": [ 1, 2, 3]}}');
      var advanceToken = tokens.next!;
      while (advanceToken.lexeme != '{') {
        advanceToken = advanceToken.next!;
      }
      advanceToken = advanceToken.next!;
      expect(tokens.lexeme, '{');
      expect(advanceToken.lexeme, '"serialNo"');
    });
    test('Tokens with comment', () {
      var tokens = Lexer().scan(
          '{//注释信息\n"name": "you", //注释\n"age": 23, "child": true, "obj": { "serialNo": [ 1, 2, 3]}}');
      var advanceToken = tokens;
      while (!advanceToken.isEof) {
        if (advanceToken.precedingComments != null) {
          print(
              '${advanceToken.lexeme} with comments: ${advanceToken.precedingComments!.toString()}');
        } else {
          print(advanceToken.lexeme);
        }

        advanceToken = advanceToken.next!;
      }
      advanceToken = advanceToken.next!;
      expect(tokens.lexeme, '{');
      // expect(advanceToken.lexeme, '"serialNo"');
    });
  });

  group('Anylyzer', () {
    test('Anlyze 1', () {
      var error = JsonAnalyzer().analyze(
          '{"name": "you", "age": 23, "child": true, "obj": { "serialNo": [ 1, 2, 3]}}');
      expect(error, null);
    });

    test('Anlyze 2', () {
      var error = JsonAnalyzer().analyze(
          '{\n   "name": "you""name":, "age": 23, "child": true, "obj": { "serialNo": [ 1, 2, 3]}}');
      var passed = error != null;
      expect(passed, true);
    });

    test('Anlyze 2', () {
      var error = JsonAnalyzer().analyze(
          '{\n   "name": "you", "age": 23, "child": true, "obj": { "serialNo": [ 1, 2, 3]}');
      var passed = error != null;
      expect(passed, true);
    });
  });
}
