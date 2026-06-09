use crate::typechecker::Type;

#[derive(Debug, Clone)]
pub struct Program {
    pub statements: Vec<Statement>,
}

#[derive(Debug, Clone)]
pub enum Statement {
    FunctionDecl {
        name: String,
        body: BlockStatement,
    },
    VarDecl {
        name: String,
        is_mut: bool,
        value: Expression,
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
    // unsafe { body }
    UnsafeBlock {
        body: BlockStatement,
    },
    Defer {
        expr: Expression,
    },
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
    Move(Box<Expression>),
    Take(Box<Expression>),
    // Pointer address-of: &expr (e.g., &ctx[node].SessionID)
    AddressOf(Box<Expression>),
    // Pointer dereference: *expr (e.g., *rawPtr)
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
