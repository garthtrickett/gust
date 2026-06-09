use crate::typechecker::Type;

#[derive(Debug, Clone)]
pub struct Program {
    pub statements: Vec<Statement>,
}

#[derive(Debug, Clone)]
pub struct FieldDef {
    pub name: String,
    pub field_type: Type,
}

#[derive(Debug, Clone)]
pub struct Parameter {
    pub name: String,
    pub param_type: Type,
}

#[derive(Debug, Clone)]
pub struct VariantDef {
    pub name: String,
    pub fields: Vec<FieldDef>,
}

#[derive(Debug, Clone)]
pub struct MatchCase {
    pub variant_name: String,
    pub body: BlockStatement,
}

#[derive(Debug, Clone)]
pub enum Statement {
    StructDecl {
        name: String,
        generics: Vec<String>,
        fields: Vec<FieldDef>,
    },
    EnumDecl {
        name: String,
        generics: Vec<String>,
        variants: Vec<VariantDef>,
    },
    FunctionDecl {
        name: String,
        params: Vec<Parameter>,
        return_type: Type,
        body: BlockStatement,
    },
    VarDecl {
        name: String,
        is_mut: bool,
        value: Option<Expression>,
        var_type: Option<Type>,
    },
    Assignment {
        left: Expression,
        value: Expression,
    },
    While {
        condition: Expression,
        body: BlockStatement,
    },
    If {
        condition: Expression,
        consequence: BlockStatement,
        alternative: Option<BlockStatement>,
    },
    Match {
        expression: Expression,
        cases: Vec<MatchCase>,
    },
    UnsafeBlock {
        body: BlockStatement,
    },
    Defer {
        expr: Expression,
    },
    Return(Option<Expression>),
    Expression(Expression),
}

#[derive(Debug, Clone)]
pub struct BlockStatement {
    pub statements: Vec<Statement>,
}

#[derive(Debug, Clone)]
pub enum Expression {
    Identifier(String),
    Integer(i64),
    String(String), // Added for String Views
    Move(Box<Expression>),
    Take(Box<Expression>),
    AddressOf(Box<Expression>),
    Dereference(Box<Expression>),
    IndexAccess {
        allocator: Box<Expression>,
        index: Box<Expression>,
    },
    AsCast {
        left: Box<Expression>,
        target_type: Type,
        is_reference: bool,
    },
    Binary {
        op: String,
        left: Box<Expression>,
        right: Box<Expression>,
    },
    Selector {
        left: Box<Expression>,
        right: String,
    },
    Call {
        function: Box<Expression>,
        arguments: Vec<Expression>,
    },
}
