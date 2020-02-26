
import 'package:markright/elements.dart';

class Walker<T> {
  Map<String, Function> commandFuncs = {};
  List<String> stack = [];

  push(x) => stack.add(x);
  pop() => stack.removeAt(stack.length - 1);

  bool inEnv(List cmdNames) {
    var i = 0;
    for (int k = 0; k < this.stack.length; k++) {
      if (this.stack[k] == cmdNames[i]) {
        i++;
        if (i >= cmdNames.length) {
          break;
        }
      }
    }
    return i == cmdNames.length;
  }

  T _invoke(fnName, Element e, List<String> args, children) {
    if (commandFuncs.containsKey(fnName)) {
      final T result = commandFuncs[fnName](e, args, children);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  List<T> _walkList(elems) {
    List<T> result = [];
    for (var e in elems) {
      final T r = _walk(e);
      if (r == null) {
        continue;
      }
      result.add(r);
    }
    return result;
  }

  T _walkEmpty(e) => _invoke('\$null', e, null, null);
  T _walkText(e) => _invoke('\$text', e, null, e.text);

  T _walkCommand(e) {
    push(e.cmd);
    var childResults = _walkList(e.children);
    var result = _invoke(e.cmd, e, e.args, childResults);
    if (result == null) {
      result = _invoke('\$command', e, e.args, childResults);
    }
    pop();
    return result;
  }

  T _walkLine(e) {
    push('\$line');
    List<T> childResults = _walkList(e.children);
    T result = _invoke('\$line', e, null, childResults);
    pop();
    return result;
  }

  T _walkRoot(e) {
    var childResults = _walkList(e.children);
    return _invoke('\$root', null, null, childResults);
  }

  T _walk(e) {
    // print('${this.stack} $e');
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
    } else if (e is RootElement) {
      return _walkRoot(e);
    } else {
      assert(false);
      return null;
    }
  }

  T walk(mr, [commandFuncs = null]) {
    var oldCommandFuncs = <String, Function>{}
      ..addAll(this.commandFuncs);
    if (commandFuncs != null) {
      this.commandFuncs.addAll(commandFuncs);
    }
    final T result = _walk(mr);
    this.commandFuncs = oldCommandFuncs;
    return result;
  }
}
