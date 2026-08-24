#include <pthread.h>

int phase20_protected_access_lifecycle_probe(void) {
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    int cycle = 0;
    while (cycle < 4) {
        if (pthread_mutex_lock(&mutex) != 0) {
            return 71;
        }
        if (pthread_mutex_unlock(&mutex) != 0) {
            return 71;
        }
        if (pthread_mutex_trylock(&mutex) != 0) {
            return 71;
        }
        if (pthread_mutex_unlock(&mutex) != 0) {
            return 71;
        }
        cycle += 1;
    }
    if (pthread_mutex_destroy(&mutex) != 0) {
        return 71;
    }
    return 72;
}
