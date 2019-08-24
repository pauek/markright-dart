import 'package:markright/markright.dart' as markright;
import 'package:test/test.dart';

class Test {
  String input, output;
  Test({this.input, this.output});
}

final tests = [
  Test(
    input: '@something',
    output: '[@something]',
  ),
  Test(
    input: '@a@b@c',
    output: '[[@*a, @*b, @*c]]',
  ),
  Test(
    input: '@a  @b@c',
    output: '[[@*a, "  ", @*b, @*c]]',
  ),
  Test(
    input: '''@a@b@c
@d@e''',
    output: '[[@*a, @*b, @*c], [@*d, @*e]]',
  ),
  Test(
    input: '@mycmd(  a   ,   b,    c   )',
    output: '[@mycmd(a, b, c)]',
  ),
  Test(
    input: '@mycmd(  a   ,   b,    c   ) @two @three',
    output: '[[@*mycmd(a, b, c), " ", @*two, " ", @*three]]',
  ),
  Test(
    input: '''
    
@eatemptylinesatthebeginning
''',
    output: '[@eatemptylinesatthebeginning]',
  ),
  Test(
    input: '''
@something
  
  Also eat the first null child
''',
    output: '[@something{"Also eat the first null child"}]',
  ),
  Test(input: '''
@main
  @a
  @b
  @c
''', output: '[@main{@a, @b, @c}]'),
  Test(
    input: '''
@first
  @a
@second
  @b
''',
    output: '[@first{@a}, @second{@b}]',
  ),
  Test(
    input: '''
@command
  1st
    2nd
  3rd
''',
    output: '[@command{"1st", "  2nd", "3rd"}]',
  ),
  Test(
    input: '''
@command
    1st
    2nd
  3rd
''',
    output: '[@command{"  1st", "  2nd", "3rd"}]',
  ),
  Test(
    input: '''
@main
  abc

  def
''',
    output: '[@main{"abc", null, "def"}]',
  )
];

void main() {
  test("parser returns something", () {
    for (var t in tests) {
      var result = markright.parse(t.input);
      expect(result.toString(), equals(t.output));
    }
  });

  test("just a test", () {
    var w = markright.Walker<String>();
    var funcs = {
      "test": (e, args) => '${e}',
      "hi": (e, args) => '$e',
      "\$text": (e, args) => '"${e.text}"',
    };
    var mr = markright.parse('@test hola @hi');
    var result = w.walk(mr, funcs);
    expect(result.toString(), equals('[[@*test, " hola ", @*hi]]'));
  });
}
