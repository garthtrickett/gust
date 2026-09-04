#[linear]
#[destructor(retire_ticket)]
#[opaque]
type Ticket struct {
    token: int
}

#[private]
func retire_ticket(ticket: Ticket) {
    os.LogInt(ticket.token);
}

func acquire_ticket(token: int) Ticket {
    mut ticket: Ticket;
    ticket.token = token;
    return ticket;
}

func read_ticket(ticket: &Ticket) int {
    return ticket.token;
}
