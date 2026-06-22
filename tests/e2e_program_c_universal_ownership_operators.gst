type DataWrapper struct {
    Value: int
}

func main() {
    mut wrapper: DataWrapper;
    wrapper.Value = 100;
    
    mut movedWrapper := move wrapper;
    os.LogInt(movedWrapper.Value);
    
    mut payload := os.MockPayload();
    mut taken := take payload;
    
    os.LogInt(taken[0]);
    os.LogInt(len(taken));
}