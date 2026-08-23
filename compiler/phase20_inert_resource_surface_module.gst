#[destructor(close_guard)]
#[opaque]
type Guard struct {
    token: int,
}

#[private]
func close_guard(value: Guard) {
    mut observed := value.token;
}
