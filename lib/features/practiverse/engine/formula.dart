import 'dart:math' as math;

class FormulaException implements Exception {
  final String message;
  const FormulaException(this.message);
  @override
  String toString() => 'FormulaException: $message';
}

/// A tiny, safe expression engine for generated practicals. It is NOT eval: only numbers, declared variables,
/// the constants pi / e, + - * / ^, parentheses and a fixed list of math functions are understood.
/// The server validates the same grammar (server/practical_gen.py); both reject everything else.
///
///   expr  := term (('+'|'-') term)*        term  := unary (('*'|'/') unary)*
///   unary := ('-'|'+') unary | power       power := atom ('^' unary)?   (right associative)
///   atom  := number | name | name '(' args ')' | '(' expr ')'
class Formula {
  final String source;
  final Set<String> variables;
  final _Node _root;

  Formula._(this.source, this.variables, this._root);

  static const Map<String, int> _arity = {
    'sqrt': 1, 'ln': 1, 'log10': 1, 'log': 1, 'exp': 1, 'sin': 1, 'cos': 1, 'tan': 1, 'asin': 1, 'acos': 1,
    'atan': 1, 'abs': 1, 'floor': 1, 'ceil': 1, 'round': 1, 'min': 2, 'max': 2, 'pow': 2,
  };

  /// Parses [source] allowing only the [allowed] variable names.
  static Formula parse(String source, Set<String> allowed) {
    if (source.trim().isEmpty || source.length > 200) throw const FormulaException('bad expression length');
    final tokens = _tokenize(source);
    final p = _Parser(tokens, allowed);
    final root = p.parseAll();
    return Formula._(source, allowed, root);
  }

  /// The value for [env], or null when it is undefined or not finite (division by zero, sqrt of a negative, ...).
  double? evaluate(Map<String, double> env) {
    try {
      final v = _root.eval(env);
      return v.isFinite ? v : null;
    } on Object {
      return null;
    }
  }

  static List<_Tok> _tokenize(String src) {
    final out = <_Tok>[];
    final re = RegExp(r'\s*(?:(\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+)|([A-Za-z_][A-Za-z0-9_]*)|(.))');
    var pos = 0;
    final s = src.trim();
    while (pos < s.length) {
      final m = re.matchAsPrefix(s, pos);
      if (m == null || m.end == pos) throw const FormulaException('bad character');
      if (m.group(1) != null) {
        out.add(_Tok('num', m.group(1)!));
      } else if (m.group(2) != null) {
        out.add(_Tok('id', m.group(2)!));
      } else {
        final op = m.group(3)!;
        if (!'+-*/^(),'.contains(op)) throw FormulaException("unexpected '$op'");
        out.add(_Tok('op', op));
      }
      pos = m.end;
    }
    return out;
  }
}

class _Tok {
  final String kind, text;
  const _Tok(this.kind, this.text);
}

abstract class _Node {
  double eval(Map<String, double> env);
}

class _Num extends _Node {
  final double v;
  _Num(this.v);
  @override
  double eval(Map<String, double> env) => v;
}

class _Var extends _Node {
  final String name;
  _Var(this.name);
  @override
  double eval(Map<String, double> env) => env[name] ?? double.nan;
}

class _Neg extends _Node {
  final _Node a;
  _Neg(this.a);
  @override
  double eval(Map<String, double> env) => -a.eval(env);
}

class _Bin extends _Node {
  final String op;
  final _Node a, b;
  _Bin(this.op, this.a, this.b);
  @override
  double eval(Map<String, double> env) {
    final x = a.eval(env), y = b.eval(env);
    switch (op) {
      case '+':
        return x + y;
      case '-':
        return x - y;
      case '*':
        return x * y;
      case '/':
        return y == 0 ? double.nan : x / y;
      default:
        return math.pow(x, y).toDouble();
    }
  }
}

class _Fn extends _Node {
  final String name;
  final List<_Node> args;
  _Fn(this.name, this.args);
  @override
  double eval(Map<String, double> env) {
    final v = [for (final a in args) a.eval(env)];
    switch (name) {
      case 'sqrt':
        return v[0] < 0 ? double.nan : math.sqrt(v[0]);
      case 'ln':
        return v[0] <= 0 ? double.nan : math.log(v[0]);
      case 'log10':
      case 'log':
        return v[0] <= 0 ? double.nan : math.log(v[0]) / math.ln10;
      case 'exp':
        return math.exp(v[0]);
      case 'sin':
        return math.sin(v[0]);
      case 'cos':
        return math.cos(v[0]);
      case 'tan':
        return math.tan(v[0]);
      case 'asin':
        return math.asin(v[0]);
      case 'acos':
        return math.acos(v[0]);
      case 'atan':
        return math.atan(v[0]);
      case 'abs':
        return v[0].abs();
      case 'floor':
        return v[0].floorToDouble();
      case 'ceil':
        return v[0].ceilToDouble();
      case 'round':
        return v[0].roundToDouble();
      case 'min':
        return math.min(v[0], v[1]);
      case 'max':
        return math.max(v[0], v[1]);
      default:
        return math.pow(v[0], v[1]).toDouble();
    }
  }
}

class _Parser {
  final List<_Tok> t;
  final Set<String> vars;
  int i = 0;
  _Parser(this.t, this.vars);

  _Tok? get peek => i < t.length ? t[i] : null;
  bool _isOp(String op) => peek != null && peek!.kind == 'op' && peek!.text == op;

  _Tok _eat() {
    if (peek == null) throw const FormulaException('unexpected end');
    return t[i++];
  }

  _Node parseAll() {
    final n = _expr();
    if (i != t.length) throw const FormulaException('trailing input');
    return n;
  }

  _Node _expr() {
    var n = _term();
    while (_isOp('+') || _isOp('-')) {
      final op = _eat().text;
      n = _Bin(op, n, _term());
    }
    return n;
  }

  _Node _term() {
    var n = _unary();
    while (_isOp('*') || _isOp('/')) {
      final op = _eat().text;
      n = _Bin(op, n, _unary());
    }
    return n;
  }

  _Node _unary() {
    if (_isOp('-') || _isOp('+')) {
      final op = _eat().text;
      final inner = _unary();
      return op == '-' ? _Neg(inner) : inner;
    }
    return _power();
  }

  _Node _power() {
    final base = _atom();
    if (_isOp('^')) {
      _eat();
      return _Bin('^', base, _unary());
    }
    return base;
  }

  _Node _atom() {
    final tk = _eat();
    if (tk.kind == 'num') return _Num(double.parse(tk.text));
    if (tk.kind == 'id') {
      final name = tk.text;
      if (_isOp('(')) {
        final arity = Formula._arity[name];
        if (arity == null) throw FormulaException('unknown function $name');
        _eat();
        final args = <_Node>[_expr()];
        while (_isOp(',')) {
          _eat();
          args.add(_expr());
        }
        if (!_isOp(')')) throw const FormulaException('missing )');
        _eat();
        if (args.length != arity) throw FormulaException('$name takes $arity argument(s)');
        return _Fn(name, args);
      }
      if (vars.contains(name)) return _Var(name);
      if (name == 'pi') return _Num(math.pi);
      if (name == 'e') return _Num(math.e);
      throw FormulaException('unknown name $name');
    }
    if (tk.text == '(') {
      final n = _expr();
      if (!_isOp(')')) throw const FormulaException('missing )');
      _eat();
      return n;
    }
    throw const FormulaException('unexpected token');
  }
}
