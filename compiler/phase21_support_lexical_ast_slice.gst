// Patch 21.12 support-library qualification root.
//
// This source imports the non-selected support modules from the live
// lexical_ast_foundations compiler slice.  Patch 21.13 owns lexer.gst itself.
import "token.gst" as token_support;
import "errors.gst" as errors_support;
import "ast.gst" as ast_support;

func main() int {
    return 0;
}
