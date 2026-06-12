import "token.gst" as token;

type ErrorKind enum {
    LexerError,
    ParserError,
    TypeError,
    CodegenError
}

type CompilerError struct {
    kind: ErrorKind,
    message: str,
    span: token.Span
}

type Result[T, ctx] enum {
    Ok { val: T },
    Err { error: Index[CompilerError, ctx] }
}