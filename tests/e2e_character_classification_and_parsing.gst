func main() {
    mut s := "   -42069   ";
    mut start := 0;
    mut end := len(s);
    
    while start < len(s) {
        mut b := std.str_byte_at(s, start);
        if std.is_whitespace(b) {
            start = start + 1;
        } else {
            end = start;
            start = len(s);
        }
    }
    mut num_start := end;
    
    mut num_end := num_start;
    mut loop_active := 1;
    while loop_active == 1 {
        if num_end < len(s) {
            mut b := std.str_byte_at(s, num_end);
            if std.is_whitespace(b) {
                loop_active = 0;
            } else {                num_end = num_end + 1;
            }
        } else {
            loop_active = 0;
        }
    }
    
    mut num_slice := std.str_slice(s, num_start, num_end);
    
    mut idx := 0;
    mut is_valid := 1;
    while idx < len(num_slice) {
        mut b := std.str_byte_at(num_slice, idx);
        if idx == 0 {
            if b == 45 {
                // negative sign '-'
            } else {
                if std.is_digit(b) {
                    // digit
                } else {
                    is_valid = 0;
                }
            }
        } else {
            if std.is_digit(b) {
                // digit
            } else {
                is_valid = 0;
            }
        }
        idx = idx + 1;
    }
    
    if is_valid == 1 {
        mut val := std.parse_int(num_slice);
        mut result := val * 2;
        os.LogInt(result);
    } else {
        os.LogInt(0);
    }
}