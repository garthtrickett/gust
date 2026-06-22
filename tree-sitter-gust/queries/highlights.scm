; ==============================================================================
; Gust Tree-sitter Highlight Queries
; ==============================================================================

; --- Keywords ---

[
  "import"
  "as"
  "type"
  "struct"
  "enum"
  "func"
  "mut"
  "defer"
  "move"
  "take"
  "unsafe"
  "empty"
] @keyword

[
  "if"
  "else"
  "while"
  "match"
  "guard"
  "return"
] @keyword.control


; --- Built-in & Custom Types ---

; Capitalized identifiers are conventionally types in Gust
(type_identifier) @type

; Built-in primitive types represented as plain identifiers
((identifier) @type.builtin
  (#anyof? @type.builtin "int" "byte" "bool" "str" "Arena" "void"))


; --- Brand / Lifetime / Type Parameters ---

; Targets type variables like 'ctx' in MyStruct[ctx] or Index[Node, ctx] using context matching
(type_parameter_list (type_identifier) @type.parameter)
(type_index (type_identifier) @type.parameter)
(type_generic (type_parameter_list (type_identifier) @type.parameter))


; --- Functions & Methods ---

; Function declarations
(function_declaration 
  (identifier) @function)

; Plain function calls: my_func()
(call_expression 
  (identifier) @function.call)

; Method calls: object.method()
(call_expression 
  (selector_expression 
    (field_identifier) @function.call))


; --- Properties, Fields & Variables ---

; Field declarations inside struct/enum definitions
(field_declaration 
  (field_identifier) @property)

; Field selections: object.field
(selector_expression 
  (field_identifier) @property)

; Standard variables
(identifier) @variable


; --- Literals ---

; Double and single quoted strings
(string_literal) @string

; Integer numbers
(integer_literal) @number

; Booleans
[
  "true"
  "false"
] @boolean


; --- Operators & Punctuation ---

[
  ":="
  "="
  "=="
  "!="
  "=>"
  "&&"
  "||"
  "+"
  "-"
  "*"
  "/"
  "<"
  ">"
  "<="
  ">="
  "&"
] @operator

[
  "("
  ")"
  "{"
  "}"
  "["
  "]"
  ";"
  ","
  "."
  ":"
] @punctuation.bracket


; --- Comments ---

(comment) @comment
