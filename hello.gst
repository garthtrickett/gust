type Client[arena] struct {
    ClientID: int,
    Balance: int
}

func chargeClient(ctx: &Arena, c: Index[Client, ctx], amount: int) {
    ctx[c].Balance = ctx[c].Balance - amount;
}

func main() {
    // 1. Create a native memory arena
    mut clientCtx := os.Arena.New();
    defer clientCtx.Free();

    // 2. Allocate and initialize the Client struct on the arena
    mut user: Index[Client, clientCtx] := os.ArenaAlloc(clientCtx);
    clientCtx[user].ClientID = 101;
    clientCtx[user].Balance = 500;

    // 3. Process the logic safely via our modular function
    chargeClient(clientCtx, user, 75);

    // 4. Output the results natively
    mut prefix := "Client balance remaining:";
    os.LogStr(prefix);
    os.LogInt(clientCtx[user].Balance);
}
