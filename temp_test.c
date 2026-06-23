#include "src/runtime.c"
int main() {
    gust_loop_ticks = 10;
    if (GUST_UNLIKELY(--gust_loop_ticks <= 0)) {
        gust_yield();
    }
    return 0;
}
