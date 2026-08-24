#include <stddef.h>

int phase20_long_lived_concurrent_probe(void);

static int phase20_cross_feature_events[3];
static size_t phase20_cross_feature_event_count;

int phase20_cross_feature_resource_event(int token) {
    if (phase20_cross_feature_event_count < 3) {
        phase20_cross_feature_events[phase20_cross_feature_event_count] = token;
    }
    phase20_cross_feature_event_count += 1;
    return token;
}

int phase20_cross_feature_probe(void) {
    static const int expected[] = {57, 2, 1};
    if (phase20_cross_feature_event_count != 3) {
        return 82;
    }
    for (size_t index = 0; index < 3; index += 1) {
        if (phase20_cross_feature_events[index] != expected[index]) {
            return 83;
        }
    }
    return phase20_long_lived_concurrent_probe();
}
