
            import 'token.gst' as token;
            import 'lexer.gst' as lexer;
            import 'parser.gst' as parser;
            import 'ast.gst' as ast;
            func main() {
                mut ctx := os.Arena.New();
                defer ctx.Free();

                // 1. Identifier
                mut l1: lexer.Lexer[ctx];
                lexer.init_lexer(&l1, 'my_var');
                mut p1: parser.Parser[ctx];
                parser.init_parser(&p1, &l1, ctx);
                mut expr1 := parser.parse_expression(&p1, 1, ctx);
                os.LogStr(ast.serialize_expression(expr1, 0, ctx));

                // 2. Binary and Integer
                mut l2: lexer.Lexer[ctx];
                lexer.init_lexer(&l2, '42 + 10');
                mut p2: parser.Parser[ctx];
                parser.init_parser(&p2, &l2, ctx);
                mut expr2 := parser.parse_expression(&p2, 1, ctx);
                os.LogStr(ast.serialize_expression(expr2, 0, ctx));

                // 3. String & Bool
                mut l3: lexer.Lexer[ctx];
                lexer.init_lexer(&l3, '\"hello\" == true');
                mut p3: parser.Parser[ctx];
                parser.init_parser(&p3, &l3, ctx);
                mut expr3 := parser.parse_expression(&p3, 1, ctx);
                os.LogStr(ast.serialize_expression(expr3, 0, ctx));

                // 4. Selector & IndexAccess
                mut l4: lexer.Lexer[ctx];
                lexer.init_lexer(&l4, 'ctx[n].val');
                mut p4: parser.Parser[ctx];
                parser.init_parser(&p4, &l4, ctx);
                mut expr4 := parser.parse_expression(&p4, 1, ctx);
                os.LogStr(ast.serialize_expression(expr4, 0, ctx));

                // 5. Call & Cast & Empty
                mut l5: lexer.Lexer[ctx];
                lexer.init_lexer(&l5, 'my_func(empty[int] as *int)');
                mut p5: parser.Parser[ctx];
                parser.init_parser(&p5, &l5, ctx);
                mut expr5 := parser.parse_expression(&p5, 1, ctx);
                os.LogStr(ast.serialize_expression(expr5, 0, ctx));
            }
        