func wrong_brand(origin: &Arena, destination: &Arena) std.Channel[int, origin] {
    return std.ChannelNew(destination);
}

func main() {
}
