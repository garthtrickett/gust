func trusted_scope_from_context(scope_identity: str) int {
    return 7;
}

func main() int {
    return trusted_scope_from_context("workspace_id");
}
