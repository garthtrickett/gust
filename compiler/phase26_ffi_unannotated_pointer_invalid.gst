extern func os_LogStr(value: str);

func main() int {
    unsafe { os_LogStr("unannotated"); }
    return 0;
}
