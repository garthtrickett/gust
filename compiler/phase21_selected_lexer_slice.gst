// Patch 21.13 selected compiler-module qualification root.
//
// Lexer is the first representative module after the Patch 21.12 support
// population. The entry is intentionally inert so qualification observes the
// imported compiler module rather than adding a source-behaviour requirement.
import "lexer.gst" as lexer;

func main() int {
    return 0;
}
