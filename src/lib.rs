pub mod ast;
pub mod codegen;
pub mod codegen_runtime;
pub mod lexer;
pub mod parser;
pub mod resolver;
pub mod token;
pub mod typechecker;

pub fn init_logging() {
    let _ = tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .try_init();
}
