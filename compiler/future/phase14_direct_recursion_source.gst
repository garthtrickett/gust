// Future positive fixture: direct recursion after SCC policy is implemented.
func countdown(value: int) int {
    if value > 0 {
        return countdown(value - 1);
    }
    return 0;
}

func main() int {
    return countdown(3);
}