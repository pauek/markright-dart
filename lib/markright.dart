
import 'package:markright/elements.dart';

const DEFAULT_CONTROL_CHARACTER = '@';
const DELIMITERS = '{}[]<>';
const TAB_WIDTH = 2;

final openDelimiters = [
  for (int i = 0; i < DELIMITERS.length; i += 2) DELIMITERS[i]
].join('');

bool foundIn(String text, String ch) => text.indexOf(ch) != -1;
bool isDelimiter(ch) => foundIn(DELIMITERS, ch);
bool isOpenDelimiter(ch) => foundIn(openDelimiters, ch);
String closeDelimFor(ch) => DELIMITERS[DELIMITERS.indexOf(ch) + 1];
bool isCharAt(String text, String ch, int i) =>
    (ch == null ? false : text.indexOf(ch, i) == i);

final error = (msg) => throw new Exception(msg);

final allSpaces = (str) => RegExp(r'^\s*$').hasMatch(str);

class Line {
  int level;
  String text;
  Line(this.level, this.text);
}

class FullLineCommand {
  String id;
  List<String> args;
  FullLineCommand(this.id, this.args);
}

class ParseLineResult {
  List<Element> elems = [];
  int end = -1;
}

class ParseInlineCommandResult {
  final CommandElement cmd;
  final int end;
  ParseInlineCommandResult(this.cmd, this.end);
}


class _Parser {
  final Map<String, Function> commandFuncs;
  final String controlChar;
  List<Element> stack;

  _Parser({
    this.commandFuncs = const {},
    this.controlChar = DEFAULT_CONTROL_CHARACTER,
  });

  _addToParent(Element x, int level) {
    final parent = this.stack[level];
    if (x == null && parent.children.length == 0) {
      return;
    }
    parent.children.add(x);
  }

  Line _parseIndentation(str) {
    var match = RegExp(r'^(\s*)(.*)$').matchAsPrefix(str);
    String space = match.group(1);
    String text = match.group(2);
    if (space.length % 2 == 1) {
      error("Indentation is not a multiple of TAB_WIDTH"
          " (= ${TAB_WIDTH}): '${str}'");
    }
    final int level = space.length ~/ 2;
    return Line(level, text);
  }

  FullLineCommand _getFullLineCommand(line) {
    var m = RegExp(r'@([a-z]+)(\((.*)\))?\s*$').matchAsPrefix(line);
    if (m == null) {
      return null;
    }
    final cmd = m.group(1);
    final args = m.group(3);
    final argList = (args != null ? args.split(',') : <String>[]);
    return FullLineCommand(cmd, argList);
  }

  _parseInlineCommand(String text, i, closeDelim) {
    var C = CommandElement.inline();
    final stopAt = ' @()' + DELIMITERS;
    while (i < text.length && !foundIn(stopAt, text[i])) {
      C.cmd += text[i++];
    }
    if (i < text.length && text[i] == '(') {
      var arg = '';
      while (text[++i] != ')') {
        if (i >= text.length) {
          error('End of string while parsing args');
        }
        if (text[i] == ',') {
          C.args.add(arg.trim());
          arg = '';
        } else {
          arg += text[i];
        }
      }
      C.args.add(arg.trim());
      i++;
    }
    var end = i;
    if (!isCharAt(text, closeDelim, i) &&
        i < text.length &&
        isDelimiter(text[i])) {
      final delimChar = text[i];
      if (!isOpenDelimiter(delimChar)) {
        error('Unexpected delimiter "$delimChar"');
      }
      C.delim.open = delimChar;
      i++;
      while (text[i] == delimChar) {
        C.delim.open += text[i++];
      }
      C.delim.close = closeDelimFor(delimChar) * C.delim.open.length;
      var result = this._parseLine(text.substring(i), C.delim.close);
      C.children = result.elems;
      i += result.end;
      if (!isCharAt(text, C.delim.close, i)) {
        error('Close delimiter for ${C.delim.open} not found');
      }
      end = i + C.delim.close.length;
    }
    return ParseInlineCommandResult(C, end);
  }

  ParseLineResult _parseLine(String text, String closeDelim) {
    var result = ParseLineResult();
    var curr = '';
    var i = 0;

    atControl() => text[i] == this.controlChar;
    closeDelimAt(k) =>
        (closeDelim != null && isCharAt(text, closeDelim, k));
    nextIsControl() => text[i + 1] == this.controlChar;
    lastChar() => (i + 1 == text.length) || closeDelimAt(i + 1);

    while (i < text.length) {
      if (atControl() && (nextIsControl() || lastChar())) {
        curr += this.controlChar;
        i += 2;
      } else if (closeDelimAt(i)) {
        break;
      } else if (atControl()) {
        if (curr.length > 0) {
          result.elems.add(TextElement(curr));
          curr = '';
        }
        var ret = this._parseInlineCommand(text, i + 1, closeDelim);
        result.elems.add(ret.cmd);
        i = ret.end;
      } else {
        curr += text[i++];
      }
    }
    if (curr.length > 0) {
      result.elems.add(TextElement(curr));
    }
    result.end = i;
    return result;
  }

  CommandElement _parseCommand(
      int level, String id, List<String> args) {
    List<String> arglist = [];
    if (args != null) {
      arglist.addAll(args.map((x) => x.trim()));
    }
    final cmd = CommandElement(id, arglist);
    if (level == this.stack.length - 1) {
      this.stack.add(cmd);
    } else {
      this.stack[level + 1] = cmd;
      this.stack.removeRange(level + 2, this.stack.length);
    }
    return cmd;
  }

  _parse(String input) {
    final lines = input.split('\n');
    this.stack = [RootElement([])];
    var emptyLine = false;
    for (var ln in lines) {
      if (allSpaces(ln)) {
        emptyLine = true;
        continue;
      }
      Line line = _parseIndentation(ln);
      final cmd = _getFullLineCommand(line.text);
      if (line.level > this.stack.length - 1) {
        if (cmd != null) {
          error('Indentation level too deep at: "${ln}"');
        } else {
          // Accept lines with excess indentation
          line.level = this.stack.length - 1;
          line.text = ln.substring(2 * line.level);
        }
      }
      Element elem;
      if (cmd != null) {
        elem = this._parseCommand(line.level, cmd.id, cmd.args);
      } else {
        var result = this._parseLine(line.text, null).elems;
        // if (result.length == 1) {
        //   elem = result.first;
        // } else {
        elem = LineElement(result);
        // }
      }
      if (emptyLine) {
        this._addToParent(null, line.level);
      }
      this._addToParent(elem, line.level);
      emptyLine = false;
    }
    return this.stack[0];
  }
}

final _parser = new _Parser();
parse(String input) => _parser._parse(input);

