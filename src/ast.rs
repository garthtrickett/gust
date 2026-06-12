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
