

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

class RootElement extends ListElement {
  RootElement(List<Element> list) : super(list);
  toString() => '<root>' + super.toString();
}

class LineElement extends ListElement {
  LineElement(List<Element> lst) : super(lst);
}

class Delimiters {
  String open, close;
  Delimiters({this.open, this.close});
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