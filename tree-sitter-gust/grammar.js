module.exports = grammar({
  name: 'gust',

  extras: $ => [
    /\s/,
    $.comment
  ],

  conflicts: $ => [
    // Resolves the standalone _type_specifier vs type_generic lookup after cast
    [$._type_specifier, $.type_generic],
    // Resolves the namespaced_identifier vs type_identifier conflict after as cast
    [$.type_identifier, $.namespaced_identifier]
  ],

  rules: {
    source_file: $ => repeat($._definition),

    _definition: $ => choice(
      $.comment,
      $._statement_or_declaration
    ),

    comment: $ => token(seq('//', /[^\n]*/)),

    _statement_or_declaration: $ => choice(
      $.import_declaration,
      $.struct_declaration,
      $.enum_declaration,
      $.function_declaration,
      $._statement
    ),

    // import "token.gst" as token;
    import_declaration: $ => seq(
      'import',
      $.string_literal,
      optional(seq('as', $.identifier)),
      ';'
    ),

    // type FieldDef[ctx] struct { ... }
    struct_declaration: $ => seq(
      'type',
      $.type_identifier,
      optional($.type_parameter_list),
      'struct',
      '{',
      repeat(seq($.field_declaration, optional(choice(',', ';')))),
      '}'
    ),

    field_declaration: $ => seq(
      $.field_identifier,
      ':',
      $._type
    ),

    // type Type[ctx] enum { ... }
    enum_declaration: $ => seq(
      'type',
      $.type_identifier,
      optional($.type_parameter_list),
      'enum',
      '{',
      repeat(seq($.variant_declaration, optional(choice(',', ';')))),
      '}'
    ),

    variant_declaration: $ => seq(
      $.type_identifier,
      optional(seq(
        '{',
        repeat(seq($.field_declaration, optional(choice(',', ';')))),
        '}'
      ))
    ),

    // func updateNode(ctx: &Arena, node: Index[CustomNode, ctx]) { ... }
    function_declaration: $ => seq(
      'func',
      $.identifier,
      $.parameter_list,
      optional($._type),
      $.block
    ),

    parameter_list: $ => seq(
      '(',
      sepBy(',', $.parameter_declaration),
      ')'
    ),

    parameter_declaration: $ => seq(
      $.identifier,
      ':',
      $._type
    ),

    block: $ => seq(
      '{',
      repeat($._statement),
      '}'
    ),

    _statement: $ => choice(
      $.variable_declaration,
      $.assignment_statement,
      $.while_statement,
      $.if_statement,
      $.match_statement,
      $.guard_statement,
      $.unsafe_statement,
      $.defer_statement,
      $.return_statement,
      $.expression_statement
    ),

    // mut x: int := 10; or x := 42;
    variable_declaration: $ => seq(
      optional('mut'),
      $.identifier,
      optional(seq(':', $._type)),
      ':=',
      $._expression,
      ';'
    ),

    assignment_statement: $ => seq(
      $._expression,
      '=',
      $._expression,
      ';'
    ),

    while_statement: $ => seq(
      'while',
      $._expression,
      $.block
    ),

    if_statement: $ => seq(
      'if',
      $._expression,
      $.block,
      optional(seq(
        'else',
        choice($.block, $.if_statement)
      ))
    ),

    match_statement: $ => seq(
      'match',
      $._expression,
      '{',
      repeat(seq($.match_case, optional(','))),
      '}'
    ),

    match_case: $ => seq(
      $.type_identifier,
      optional(seq('{', sepBy(',', $.identifier), '}')),
      '=>',
      $.block
    ),

    guard_statement: $ => seq(
      'guard',
      optional('mut'),
      $.identifier,
      ':=',
      $._expression,
      'else',
      $.block
    ),

    unsafe_statement: $ => seq(
      'unsafe',
      $.block
    ),

    defer_statement: $ => seq(
      'defer',
      $._expression,
      ';'
    ),

    return_statement: $ => seq(
      'return',
      optional($._expression),
      ';'
    ),

    expression_statement: $ => seq(
      $._expression,
      ';'
    ),

    // --- Expressions ---

    _expression: $ => choice(
      $.identifier,
      $.integer_literal,
      $.string_literal,
      $.boolean_literal,
      $.move_expression,
      $.take_expression,
      $.address_expression,
      $.dereference_expression,
      $.index_access,
      $.as_cast,
      $.binary_expression,
      $.selector_expression,
      $.call_expression,
      $.empty_expression
    ),

    string_literal: $ => $.string_literal_token,
    integer_literal: $ => $.integer_literal_token,
    boolean_literal: $ => choice('true', 'false'),

    move_expression: $ => prec(12, seq('move', $._expression)),
    take_expression: $ => prec(12, seq('take', $._expression)),
    address_expression: $ => prec(12, seq('&', $._expression)),
    dereference_expression: $ => prec(12, seq('*', $._expression)),

    index_access: $ => prec(13, seq(
      $._expression,
      '[',
      $._expression,
      ']'
    )),

    as_cast: $ => prec(11, seq(
      $._expression,
      'as',
      optional('&'),
      $._type
    )),

    binary_expression: $ => {
      const table = [
        [5, '||'],
        [6, '&&'],
        [7, '=='],
        [7, '!='],
        [8, '<'],
        [8, '>'],
        [8, '<='],
        [8, '>='],
        [9, '+'],
        [9, '-'],
        [10, '*'],
        [10, '/']
      ];

      return choice(...table.map(([precedence, operator]) => prec.left(precedence, seq(
        $._expression,
        operator,
        $._expression
      ))));
    },

    selector_expression: $ => prec(13, seq(
      $._expression,
      '.',
      $.field_identifier
    )),

    call_expression: $ => prec(13, seq(
      $._expression,
      '(',
      sepBy(',', $._expression),
      ')'
    )),

    empty_expression: $ => seq(
      'empty',
      '[',
      $._type,
      ']'
    ),

    // --- Types ---

    _type: $ => choice(
      $._type_specifier,
      $.pointer_type,
      $.slice_type
    ),

    _type_specifier: $ => choice(
      $.primitive_type,
      $.type_index,
      $.type_identifier,
      $.type_generic
    ),

    primitive_type: $ => choice(
      'int',
      'byte',
      'bool',
      'str',
      'Arena',
      'void'
    ),

    pointer_type: $ => seq('*', $._type),

    slice_type: $ => seq('[', ']', $._type),

    type_index: $ => seq(
      'Index',
      '[',
      $._type,
      optional(seq(',', $._type)),
      ']'
    ),

    type_generic: $ => seq(
      choice($.namespaced_identifier, $.type_identifier),
      $.type_parameter_list
    ),

    // --- Type Helpers ---

    type_parameter: $ => $.identifier,

    brand_identifier: $ => $.identifier,

    // --- Core Identifiers ---

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    type_identifier: $ => $.identifier,

    field_identifier: $ => $.identifier,

    // --- Helper Rules ---

    namespaced_identifier: $ => seq(
      $.identifier,
      repeat1(seq('.', $.identifier))
    ),

    type_parameter_list: $ => seq(
      '[',
      sepBy(',', $._type),
      ']'
    ),

    integer_literal_token: $ => /-?[0-9]+/,

    string_literal_token: $ => choice(
      seq('"', repeat(choice(/[^"\\]/, $.escape_sequence)), '"'),
      seq("'", repeat(choice(/[^'\\\\]/, $.escape_sequence)), "'")
    ),

    escape_sequence: $ => token(seq(
      '\\',
      choice(
        /[^uxU]/,
        /\d{2,3}/,
        /x[0-9a-fA-F]{2,}/,
        /u[0-9a-fA-F]{4}/,
        /U[0-9a-fA-F]{8}/
      )
    )),

    boolean_literal: $ => choice('true', 'false')
  }
});

function sepBy(sep, rule) {
  return optional(seq(rule, repeat(seq(sep, rule))));
}
