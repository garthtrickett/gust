#include "runtime/core_headers.h"

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct {
    int mutex_index;
    int *counter;
    int cycles;
} Phase20MutexWorker;

typedef struct {
    int channel_index;
    int cycles;
} Phase20ChannelWorker;

static void *phase20_mutex_worker(void *opaque) {
    Phase20MutexWorker *worker = (Phase20MutexWorker *)opaque;
    for (int cycle = 0; cycle < worker->cycles; cycle++) {
        int *value = (int *)std_Mutex_Lock_impl(
            worker->mutex_index, worker->counter);
        *value += 1;
        std_Mutex_Unlock_impl(worker->mutex_index);
    }
    return NULL;
}

static void *phase20_channel_worker(void *opaque) {
    Phase20ChannelWorker *worker = (Phase20ChannelWorker *)opaque;
    for (int value = 1; value <= worker->cycles; value++) {
        std_Channel_Send_impl(worker->channel_index, &value);
    }
    return NULL;
}

int phase20_long_lived_concurrent_probe(void) {
    const char *configured = getenv("GUST_PHASE20_LONG_LIVED_CYCLES");
    char *end = NULL;
    long parsed = configured ? strtol(configured, &end, 10) : 0;
    if (!configured || !end || *end != '\0' || parsed < 1 || parsed > 128) {
        return 90;
    }
    int cycles = (int)parsed;

    int counter = 0;
    Phase20MutexWorker mutex_worker = {
        .mutex_index = std_Mutex_Alloc(),
        .counter = &counter,
        .cycles = cycles,
    };
    pthread_t mutex_threads[2];
    if (pthread_create(&mutex_threads[0], NULL, phase20_mutex_worker,
                       &mutex_worker) != 0 ||
        pthread_create(&mutex_threads[1], NULL, phase20_mutex_worker,
                       &mutex_worker) != 0) {
        return 91;
    }
    if (pthread_join(mutex_threads[0], NULL) != 0 ||
        pthread_join(mutex_threads[1], NULL) != 0) {
        return 92;
    }
    if (counter != cycles * 2) {
        return 93;
    }

    Phase20ChannelWorker channel_worker = {
        .channel_index = std_Channel_Alloc(4, sizeof(int)),
        .cycles = cycles,
    };
    pthread_t channel_thread;
    if (pthread_create(&channel_thread, NULL, phase20_channel_worker,
                       &channel_worker) != 0) {
        return 94;
    }
    int sum = 0;
    for (int cycle = 0; cycle < cycles; cycle++) {
        int value = 0;
        std_Channel_Recv_impl(channel_worker.channel_index, &value);
        sum += value;
    }
    if (pthread_join(channel_thread, NULL) != 0) {
        return 95;
    }
    if (sum != cycles * (cycles + 1) / 2) {
        return 96;
    }
    return 47;
}
