#[linear]
#[destructor(release_ticket)]
#[opaque]
type Ticket struct {
    code: int
}

type PairBox struct {
    left: Ticket,
    right: Ticket
}

#[private]
func release_ticket(value: Ticket) {
    os.LogInt(value.code);
}

func obtain(code: int) Ticket {
    mut value: Ticket;
    value.code = code;
    return value;
}

func finish(value: Ticket) {
    release_ticket(value);
}
