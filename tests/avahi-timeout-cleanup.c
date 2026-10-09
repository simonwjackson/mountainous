/* Exercise PR 366 through Avahi's public event-loop API, not internal structs. */
#include <assert.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include <avahi-common/simple-watch.h>

static void watch_callback(AvahiWatch *watch, int fd, AvahiWatchEvent events, void *userdata) {
    (void)watch;
    (void)fd;
    (void)events;
    (void)userdata;
    abort();
}

static void timeout_callback(AvahiTimeout *timeout, void *userdata) {
    (void)timeout;
    (void)userdata;
    abort();
}

static void churn(AvahiSimplePoll *poll, int fd, unsigned iterations) {
    const AvahiPoll *api = avahi_simple_poll_get(poll);
    for (unsigned i = 0; i < iterations; ++i) {
        AvahiWatch *watch = api->watch_new(api, fd, AVAHI_WATCH_IN, watch_callback, NULL);
        AvahiTimeout *timeout = api->timeout_new(api, NULL, timeout_callback, NULL);
        assert(watch != NULL && timeout != NULL);
        api->timeout_free(timeout);
        api->watch_free(watch);
        assert(avahi_simple_poll_iterate(poll, 0) == 0);
    }
}

int main(void) {
    int pipefd[2];
    assert(pipe(pipefd) == 0);
    AvahiSimplePoll *poll = avahi_simple_poll_new();
    assert(poll != NULL);

    /* Warm up allocator and poll storage before measuring retained allocations. */
    churn(poll, pipefd[0], 200);
    size_t before = mallinfo2().uordblks;
    struct timespec start, end;
    assert(clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &start) == 0);
    churn(poll, pipefd[0], 10000);
    assert(clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &end) == 0);
    size_t after = mallinfo2().uordblks;
    size_t growth = after > before ? after - before : 0;
    double cpu_seconds = (double)(end.tv_sec - start.tv_sec)
        + (double)(end.tv_nsec - start.tv_nsec) / 1000000000.0;
    printf("10000 cleanup cycles: retained growth=%zu bytes, CPU=%.6f seconds\n", growth, cpu_seconds);

    avahi_simple_poll_free(poll);
    close(pipefd[0]);
    close(pipefd[1]);

    /* The unfixed 0.8 build retains about 1 MB of dead timeout objects. */
    if (growth > 128 * 1024) {
        fprintf(stderr, "FAIL: simultaneous watch/timeout cleanup leaks timeout objects\n");
        return 1;
    }
    puts("PASS: freed timeout objects do not accumulate during watch cleanup");
    return 0;
}
