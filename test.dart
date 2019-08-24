import 'markright.dart' as markright;
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
    output: '[[@a, @b, @c]]',
  ),
  Test(
    input: '@a  @b@c',
    output: '[[@a, "  ", @b, @c]]',
  ),
  Test(
    input: '''@a@b@c
@d@e''',
    output: '[[@a, @b, @c], [@d, @e]]',
  ),
  Test(
    input: '@mycmd(  a   ,   b,    c   )',
    output: '[@mycmd(a, b, c)]',
  ),
  Test(
    input: '@mycmd(  a   ,   b,    c   ) @two @three',
    output: '[[@mycmd(a, b, c), " ", @two, " ", @three]]',
  )
];

void main() {
  test("parser returns something", () {
    for (var t in tests) {
      var parser = markright.Parser();
      var result = parser.parse(t.input);
      expect(result.toString(), equals(t.output));
    }
  });
}
