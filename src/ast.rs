use crate::typechecker::Type;
use crate::token::Span;

#[derive(Debug, Clone)]
pub struct Program {
    pub statements: Vec<Statement>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct FieldDef {
    pub name: String,
    pub field_type: Type,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct Parameter {
    pub name: String,
    pub param_type: Type,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct VariantDef {
    pub name: String,
    pub fields: Vec<FieldDef>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct MatchCase {
    pub variant_name: String,
    pub fields: Vec<String>,
    pub body: BlockStatement,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum Statement {
    Import {
        path: String,
        alias: Option<String>,
        span: Span,
    },
    StructDecl {
        name: String,
        generics: Vec<String>,
        fields: Vec<FieldDef>,
        span: Span,
    },
    EnumDecl {
        name: String,
        generics: Vec<String>,
        variants: Vec<VariantDef>,
        span: Span,
    },
    FunctionDecl {
        name: String,
        params: Vec<Parameter>,
        return_type: Type,
        body: BlockStatement,
        span: Span,
    },
    VarDecl {
        name: String,
        is_mut: bool,
        value: Option<Expression>,
        var_type: Option<Type>,
        span: Span,
    },
    Assignment {
        left: Expression,
        value: Expression,
        span: Span,
    },
    While {
        condition: Expression,
        body: BlockStatement,
        span: Span,
    },
    If {
        condition: Expression,
        consequence: BlockStatement,
        alternative: Option<BlockStatement>,
        span: Span,
    },
    Match {
        expression: Expression,
        cases: Vec<MatchCase>,
        span: Span,
    },
    Guard {
        name: String,
        is_mut: bool,
        value: Expression,
        else_body: BlockStatement,
        span: Span,
    },
    UnsafeBlock {
        body: BlockStatement,
        span: Span,
    },
    Defer {
        expr: Expression,
        span: Span,
    },
    Return(Option<Expression>, Span),
    Expression(Expression, Span),
}

#[derive(Debug, Clone)]
pub struct BlockStatement {
    pub statements: Vec<Statement>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum Expression {
    Identifier(String, Span),
    Integer(i64, Span),
    String(String, Span), // Added for String Views
    Bool(bool, Span),
    Move(Box<Expression>, Span),
    Take(Box<Expression>, Span),
    AddressOf(Box<Expression>, Span),
    Dereference(Box<Expression>, Span),
    IndexAccess {
        allocator: Box<Expression>,
        index: Box<Expression>,
        span: Span,
    },
    AsCast {
        left: Box<Expression>,
        target_type: Type,
        is_reference: bool,
        span: Span,
    },
    Binary {
        op: String,
        left: Box<Expression>,
        right: Box<Expression>,
        span: Span,
    },
    Selector {
        left: Box<Expression>,
        right: String,
        span: Span,
    },
    Call {
        function: Box<Expression>,
        arguments: Vec<Expression>,
        span: Span,
    },
    Empty(Type, Span), // Added for empty[T] intrinsic
}

impl Statement {
    pub fn span(&self) -> Span {
        match self {
            Statement::Import { span, .. } => *span,
            Statement::StructDecl { span, .. } => *span,
            Statement::EnumDecl { span, .. } => *span,
            Statement::FunctionDecl { span, .. } => *span,
            Statement::VarDecl { span, .. } => *span,
            Statement::Assignment { span, .. } => *span,
            Statement::While { span, .. } => *span,
            Statement::If { span, .. } => *span,
            Statement::Match { span, .. } => *span,
            Statement::Guard { span, .. } => *span,
            Statement::UnsafeBlock { span, .. } => *span,
            Statement::Defer { span, .. } => *span,
            Statement::Return(_, span) => *span,
            Statement::Expression(_, span) => *span,
        }
    }
}

impl Expression {
    pub fn span(&self) -> Span {
        match self {
            Expression::Identifier(_, span) => *span,
            Expression::Integer(_, span) => *span,
            Expression::String(_, span) => *span,
            Expression::Bool(_, span) => *span,
            Expression::Move(_, span) => *span,
            Expression::Take(_, span) => *span,
            Expression::AddressOf(_, span) => *span,
            Expression::Dereference(_, span) => *span,
            Expression::IndexAccess { span, .. } => *span,
            Expression::AsCast { span, .. } => *span,
            Expression::Binary { span, .. } => *span,
            Expression::Selector { span, .. } => *span,
            Expression::Call { span, .. } => *span,
            Expression::Empty(_, span) => *span,
        }
    }
}

impl Program {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        let mut out = format!("{}Program:\n", pad);
        for stmt in &self.statements {
            out.push_str(&stmt.serialize(indent + 1));
        }
        out
    }
}

impl Parameter {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        format!("{}Parameter: {} : {:?}\n", pad, self.name, self.param_type)
    }
}

impl FieldDef {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        format!("{}FieldDef: {} : {:?}\n", pad, self.name, self.field_type)
    }
}

impl VariantDef {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        let mut out = format!("{}VariantDef: {}\n", pad, self.name);
        for f in &self.fields {
            out.push_str(&f.serialize(indent + 1));
        }
        out
    }
}

impl MatchCase {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        let mut out = format!(
            "{}MatchCase: {} [{}],\n",
            pad,
            self.variant_name,
            self.fields.join(", ")
        );
        out.push_str(&self.body.serialize(indent + 1));
        out
    }
}

impl BlockStatement {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        let mut out = format!("{}BlockStatement:\n", pad);
        for stmt in &self.statements {
            out.push_str(&stmt.serialize(indent + 1));
        }
        out
    }
}

impl Statement {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        match self {
            Statement::Import { path, alias, .. } => {
                let alias_str = alias.as_deref().unwrap_or("<none>");
                format!("{}Import: {} as {}\n", pad, path, alias_str)
            }
            Statement::StructDecl { name, generics, fields, .. } => {
                let mut out = format!("{}StructDecl: {} <{}>\n", pad, name, generics.join(", "));
                for f in fields {
                    out.push_str(&f.serialize(indent + 1));
                }
                out
            }
            Statement::EnumDecl { name, generics, variants, .. } => {
                let mut out = format!("{}EnumDecl: {} <{}>\n", pad, name, generics.join(", "));
                for v in variants {
                    out.push_str(&v.serialize(indent + 1));
                }
                out
            }
            Statement::FunctionDecl { name, params, return_type, body, .. } => {
                let mut out = format!("{}FunctionDecl: {} -> {:?}\n", pad, name, return_type);
                for p in params {
                    out.push_str(&p.serialize(indent + 1));
                }
                out.push_str(&body.serialize(indent + 1));
                out
            }
            Statement::VarDecl { name, is_mut, value, var_type, .. } => {
                let type_str = match var_type {
                    Some(t) => format!("{:?}", t),
                    None => "<inferred>".to_string(),
                };
                let mut out = format!("{}VarDecl: {} (mut={}) : {}\n", pad, name, is_mut, type_str);
                if let Some(val) = value {
                    out.push_str(&val.serialize(indent + 1));
                }
                out
            }
            Statement::Assignment { left, value, .. } => {
                let mut out = format!("{}Assignment:\n", pad);
                out.push_str(&left.serialize(indent + 1));
                out.push_str(&value.serialize(indent + 1));
                out
            }
            Statement::While { condition, body, .. } => {
                let mut out = format!("{}While:\n", pad);
                out.push_str(&condition.serialize(indent + 1));
                out.push_str(&body.serialize(indent + 1));
                out
            }
            Statement::If { condition, consequence, alternative, .. } => {
                let mut out = format!("{}If:\n", pad);
                out.push_str(&condition.serialize(indent + 1));
                out.push_str(&consequence.serialize(indent + 1));
                if let Some(alt) = alternative {
                    out.push_str(&format!("{}Else:\n", pad));
                    out.push_str(&alt.serialize(indent + 1));
                }
                out
            }
            Statement::Match { expression, cases, .. } => {
                let mut out = format!("{}Match:\n", pad);
                out.push_str(&expression.serialize(indent + 1));
                for c in cases {
                    out.push_str(&c.serialize(indent + 1));
                }
                out
            }
            Statement::Guard { name, is_mut, value, else_body, .. } => {
                let mut out = format!("{}Guard: {} (mut={})\n", pad, name, is_mut);
                out.push_str(&value.serialize(indent + 1));
                out.push_str(&else_body.serialize(indent + 1));
                out
            }
            Statement::UnsafeBlock { body, .. } => {
                let mut out = format!("{}UnsafeBlock:\n", pad);
                out.push_str(&body.serialize(indent + 1));
                out
            }
            Statement::Defer { expr, .. } => {
                let mut out = format!("{}Defer:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
            Statement::Return(maybe_expr, _) => {
                let mut out = format!("{}Return:\n", pad);
                if let Some(expr) = maybe_expr {
                    out.push_str(&expr.serialize(indent + 1));
                } else {
                    out.push_str(&format!("{}  <void>\n", pad));
                }
                out
            }
            Statement::Expression(expr, _) => {
                let mut out = format!("{}ExpressionStatement:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
        }
    }
}

impl Expression {
    pub fn serialize(&self, indent: usize) -> String {
        let pad = "  ".repeat(indent);
        match self {
            Expression::Identifier(name, _) => {
                format!("{}Identifier: {}\n", pad, name)
            }
            Expression::Integer(val, _) => {
                format!("{}Integer: {}\n", pad, val)
            }
            Expression::String(val, _) => {
                format!("{}String: \"{}\"\n", pad, val)
            }
            Expression::Bool(val, _) => {
                format!("{}Bool: {}\n", pad, val)
            }
            Expression::Move(expr, _) => {
                let mut out = format!("{}Move:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
            Expression::Take(expr, _) => {
                let mut out = format!("{}Take:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
            Expression::AddressOf(expr, _) => {
                let mut out = format!("{}AddressOf:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
            Expression::Dereference(expr, _) => {
                let mut out = format!("{}Dereference:\n", pad);
                out.push_str(&expr.serialize(indent + 1));
                out
            }
            Expression::IndexAccess { allocator, index, .. } => {
                let mut out = format!("{}IndexAccess:\n", pad);
                out.push_str(&allocator.serialize(indent + 1));
                out.push_str(&index.serialize(indent + 1));
                out
            }
            Expression::AsCast { left, target_type, is_reference, .. } => {
                let mut out = format!("{}AsCast: {:?} (ref={})\n", pad, target_type, is_reference);
                out.push_str(&left.serialize(indent + 1));
                out
            }
            Expression::Binary { op, left, right, .. } => {
                let mut out = format!("{}Binary: {}\n", pad, op);
                out.push_str(&left.serialize(indent + 1));
                out.push_str(&right.serialize(indent + 1));
                out
            }
            Expression::Selector { left, right, .. } => {
                let mut out = format!("{}Selector: {}\n", pad, right);
                out.push_str(&left.serialize(indent + 1));
                out
            }
            Expression::Call { function, arguments, .. } => {
                let mut out = format!("{}Call:\n", pad);
                out.push_str(&function.serialize(indent + 1));
                for arg in arguments {
                    out.push_str(&arg.serialize(indent + 1));
                }
                out
            }
            Expression::Empty(t, _) => {
                format!("{}Empty: {:?}\n", pad, t)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ast_serialization_basic() {
        let span = Span::dummy();
        let program = Program {
            statements: vec![
                Statement::VarDecl {
                    name: "x".to_string(),
                    is_mut: true,
                    value: Some(Expression::Integer(42, span)),
                    var_type: Some(Type::Int),
                    span,
                }
            ],
            span,
        };

        let serialized = program.serialize(0);
        let expected = "Program:\n  VarDecl: x (mut=true) : Int\n    Integer: 42\n";
        assert_eq!(serialized, expected);
    }

    #[test]
    fn test_ast_serialization_binary() {
        let span = Span::dummy();
        let program = Program {
            statements: vec![
                Statement::Expression(
                    Expression::Binary {
                        op: "+".to_string(),
                        left: Box::new(Expression::Identifier("a".to_string(), span)),
                        right: Box::new(Expression::Integer(1, span)),
                        span,
                    },
                    span,
                )
            ],
            span,
        };

        let serialized = program.serialize(0);
        let expected = "Program:\n  ExpressionStatement:\n    Binary: +\n      Identifier: a\n      Integer: 1\n";
        assert_eq!(serialized, expected);
    }
}
