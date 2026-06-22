type Status struct {
    ok: bool
}

func main() {
    mut b: bool := true;
    os.LogInt(b as int);
    
    b = false;
    os.LogInt(b as int);
    
    mut s: Status;
    s.ok = true;
    os.LogInt(s.ok as int);
}
