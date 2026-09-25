import "../src/stdlib/byte_text.gst" as text;

func main() int {
    os.LogInt(text.starts_with("", ""));
    os.LogInt(text.ends_with("", ""));
    os.LogInt(text.contains("", ""));
    os.LogInt(text.starts_with("a", "ab"));
    os.LogInt(text.ends_with("a", "ab"));
    os.LogInt(text.contains("a", "ab"));
    os.LogInt(text.starts_with("hello", "hello"));
    os.LogInt(text.ends_with("hello", "hello"));
    os.LogInt(text.contains("hello", "hello"));
    os.LogInt(text.starts_with("hello", ""));
    os.LogInt(text.ends_with("hello", ""));
    os.LogInt(text.contains("hello", ""));
    os.LogInt(text.starts_with("hello", "he"));
    os.LogInt(text.ends_with("hello", "lo"));
    os.LogInt(text.contains("hello", "ell"));
    os.LogInt(text.starts_with("hello", "ell"));
    os.LogInt(text.ends_with("hello", "ell"));
    os.LogInt(text.contains("hello", "xyz"));
    os.LogInt(text.starts_with("café", "caf"));
    os.LogInt(text.ends_with("café", "fé"));
    os.LogInt(text.contains("café", "af"));
    return 0;
}
