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

Line parseIndentation(str) {
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

class Delimiters {
  String open, close;
  Delimiters({this.open, this.close});
}

class FullLineCommand {
  String id, args;
  FullLineCommand(this.id, this.args);
}

getFullLineCommand(line) {
  var m = RegExp(r'@([a-z]+)(\((.*)\))?$').matchAsPrefix(line);
  if (m == null) {
    return null;
  }
  return FullLineCommand(m.group(1), m.group(3));
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

abstract class Element {
  List<Element> get children;
}

class EmptyElement extends Element {
  List<Element> get children => [];
  toString() => 'null';
}

class TextElement extends Element {
  String text;
  TextElement(this.text);
  List<Element> get children => [];
  toString() => '"$text"';
}

class ListElement extends Element {
  List<Element> children;
  ListElement(this.children);
  toString() => '[${children.map((x) => x.toString()).join(', ')}]';
}

class LineElement extends ListElement {
  LineElement(List<Element> lst) : super(lst);
}

class CommandElement extends ListElement {
  bool inline;
  String cmd = '';
  List<String> args = [];
  Delimiters delim = Delimiters();

  CommandElement(this.cmd, this.args)
      : inline = false,
        super([]);
  CommandElement.inline()
      : inline = true,
        super([]);

  toString() {
    String _inline = '';
    if (inline) {
      _inline = '*';
    }
    String _children = '';
    if (children != null && children.length > 0) {
      _children = '{${children.map((x) => x.toString()).join(', ')}}';
    }
    String _args = '';
    if (args != null && args.length > 0) {
      _args = '(${args.join(', ')})';
    }
    return '@$_inline$cmd$_args$_children';
  }
}

class Parser {
  final Map<String, Function> commandFuncs;
  final String controlChar;
  List<Element> stack;

  Parser(
      {this.commandFuncs = const {},
      this.controlChar = DEFAULT_CONTROL_CHARACTER}) {}

  addToParent(Element x, int level) {
    final parent = this.stack[level];
    if (x == null && parent.children.length == 0) {
      return;
    }
    parent.children.add(x);
  }

  parseInlineCommand(String text, i, closeDelim) {
    var C = CommandElement.inline();
    final stopAt = ' @()' + DELIMITERS;
    while (i < text.length && !foundIn(stopAt, text[i])) {
      C.cmd += text[i++];
    }
    if (i < text.length && text[i] == '(') {
      var arg = '';
      i++;
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
      var result = this.parseLine(text.substring(i), C.delim.close);
      C.children = result.elems;
      i += result.end;
      if (!isCharAt(text, C.delim.close, i)) {
        error('Close delimiter for ${C.delim.open} not found');
      }
      end = i + C.delim.close.length;
    }
    return ParseInlineCommandResult(C, end);
  }

  ParseLineResult parseLine(String text, String closeDelim) {
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
        var ret = this.parseInlineCommand(text, i + 1, closeDelim);
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

  parseCommand(int level, String id, String args) {
    List<String> arglist = [];
    if (args != null) {
      arglist.addAll(args.split(',').map((x) => x.trim()));
    }
    final cmd = CommandElement(id, arglist);
    if (level == this.stack.length - 1) {
      this.stack.add(cmd);
    } else {
      this.stack[level + 1] = cmd;
    }
    return cmd;
  }

  parse(String input) {
    final lines = input.split('\n');
    this.stack = [ListElement([])];
    var emptyLine = false;
    for (var ln in lines) {
      if (allSpaces(ln)) {
        emptyLine = true;
        continue;
      }
      Line line = parseIndentation(ln);
      final cmd = getFullLineCommand(line.text);
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
        elem = this.parseCommand(line.level, cmd.id, cmd.args);
      } else {
        var result = this.parseLine(line.text, null).elems;
        if (result.length == 1) {
          elem = result.first;
        } else {
          elem = LineElement(result);
        }
      }
      if (emptyLine) {
        this.addToParent(null, line.level);
      }
      this.addToParent(elem, line.level);
      emptyLine = false;
    }
    return this.stack[0];
  }
}

final _parser = new Parser();
parse(String input) => _parser.parse(input);

abstract class Elem<T> {
  T value;
  Elem(this.value);
  List<Elem<T>> get children;
}

class SingleElem<T> extends Elem<T> {
  SingleElem(T value) : super(value);
  List<Elem<T>> get children => null;
  toString() => '$value';
}

class ListElem<T> extends Elem<T> {
  ListElem(T value) : super(value);
  List<Elem<T>> children = [];
  toString() => '[${children.map((e) => e.toString()).join(', ')}]';

  List<T> get values {
    List<T> result = [];
    for (var elem in children) {
      if (elem is SingleElem<T>) {
        result.add(elem.value);
      } else if (elem is ListElem<T>) {
        result.addAll(elem.values);
      }
    }
    return result;
  }
}

class Walker<T> {
  Map<String, Function> commandFuncs = {};
  List<String> stack = [];

  push(x) => stack.add(x);
  pop() => stack.removeAt(stack.length - 1);

  bool inEnv(List cmdNames) {
    var i = 0;
    for (int k = 0; k < this.stack.length; k++) {
      if (this.stack[k] == cmdNames[i]) i++;
    }
    return i == cmdNames.length;
  }

  Elem<T> _invoke(fnName, e, [args = null]) {
    if (commandFuncs.containsKey(fnName)) {
      var result = commandFuncs[fnName](e, args);
      if (result != null) {
        return SingleElem<T>(result);
      }
    }
    return null;
  }

  ListElem<T> _walkList(elems) {
    var result = ListElem<T>(null);
    for (var e in elems) {
      var r = _walk(e);
      if (r == null) {
        continue;
      }
      if (r is SingleElem<T>) {
        result.children.add(r);
      } else if (r is ListElem<T>) {
        /*
        if (r.children.length == 1) {
          result.children.add(r.children[0]);
        } else {*/
        result.children.add(r);
        // }
      }
    }
    return result;
  }

  Elem<T> _walkEmpty(e) => _invoke('\$null', null);
  Elem<T> _walkText(e) => _invoke('\$text', e);

  Elem<T> _walkCommand(e) {
    push(e.cmd);
    var childResults = _walkList(e.children);
    var result = _invoke(e.cmd, e, childResults);
    if (result == null) {
      result = _invoke('\$command', e, childResults);
    }
    pop();
    return result;
  }

  Elem<T> _walkLine(e) {
    push('\$line');
    ListElem<T> childResults = _walkList(e.children);
    var result = _invoke('\$line', e, childResults);
    pop();
    return result;
  }

  Elem<T> _walk(e) {
    if (e == null) {
      return null;
    } else if (e is EmptyElement) {
      return _walkEmpty(e);
    } else if (e is CommandElement) {
      return _walkCommand(e);
    } else if (e is TextElement) {
      return _walkText(e);
    } else if (e is LineElement) {
      return _walkLine(e);
    } else if (e is ListElement) {
      return _walkList(e.children);
    } else {
      assert(false);
      return null;
    }
  }

  Elem<T> walk(mr, [commandFuncs = null]) {
    var oldCommandFuncs = <String, Function>{}
      ..addAll(this.commandFuncs);
    if (commandFuncs != null) {
      this.commandFuncs.addAll(commandFuncs);
    }
    var result = _walk(mr);
    this.commandFuncs = oldCommandFuncs;
    return result;
  }
}
