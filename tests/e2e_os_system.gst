func main() {
    mut code := os.System("echo 'FFI_SUBPROCESS_OK'");
    os.LogInt(code);
}