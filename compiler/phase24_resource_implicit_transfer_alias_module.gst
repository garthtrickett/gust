#[linear]
#[destructor(release_permit)]
#[opaque]
type Permit struct {
    token: int
}

#[private]
func release_permit(ticket: Permit) {
    os.LogInt(ticket.token);
}

func make_permit(token: int) Permit {
    mut ticket: Permit;
    ticket.token = token;
    return ticket;
}

func inspect_permit(ticket: &Permit) int {
    return ticket.token;
}
