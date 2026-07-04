// Gust MIR scaffold.
//
// MIR is the lowered executable IR between the typechecked AST and backend
// emission. Phase 1 is intentionally inert: this file defines the future home
// for MIR data structures, but no production compiler path should depend on it
// yet.
//
// Planned pipeline:
//
//   typechecked AST / typed high-level representation
//     -> Gust MIR
//     -> MIR verifier
//     -> C backend first
//     -> Cranelift backend later
//
// Phase 1 rule:
//   Do not add AST-to-MIR lowering, MIR-to-C emission, Cranelift integration,
//   or production codegen dependencies in this file yet.

import "token.gst" as token;

type MirProgram[ctx] struct {
    functions: Index[std.Vector[MirFunction[ctx], ctx], ctx]
}

type MirFunction[ctx] struct {
    name: str,
    params: Index[std.Vector[MirLocal, ctx], ctx],
    return_type: str,
    locals: Index[std.Vector[MirLocal, ctx], ctx],
    blocks: Index[std.Vector[MirBlock[ctx], ctx], ctx],
    entry_block: int,
    span: token.Span
}

type MirBlock[ctx] struct {
    id: int,
    statements: Index[std.Vector[MirStmt[ctx], ctx], ctx],
    terminator: Index[MirTerminator[ctx], ctx],
    span: token.Span
}

type MirLocal struct {
    id: int,
    name: str,
    local_type: str,
    span: token.Span
}

type MirStmt[ctx] enum {
    Nop {
        span: token.Span
    },
    LocalSet {
        local_id: int,
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Expr {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    }
}

type MirValue[ctx] enum {
    IntLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    BoolLiteral {
        val: int,
        value_type: str,
        span: token.Span
    },
    StringLiteral {
        val: str,
        value_type: str,
        span: token.Span
    },
    LocalRead {
        local_id: int,
        value_type: str,
        span: token.Span
    },
    Call {
        callee: str,
        args: Index[std.Vector[MirValue[ctx], ctx], ctx],
        value_type: str,
        span: token.Span
    }
}

type MirTerminator[ctx] enum {
    ReturnVoid {
        span: token.Span
    },
    Return {
        value: Index[MirValue[ctx], ctx],
        span: token.Span
    },
    Jump {
        target_block: int,
        span: token.Span
    },
    Branch {
        condition: Index[MirValue[ctx], ctx],
        then_block: int,
        else_block: int,
        span: token.Span
    }
}
