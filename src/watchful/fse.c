#include "../watchful.h"

#ifndef MACOS

watchful_backend_t watchful_fse = {
    .name = "fse",
    .setup = NULL,
    .teardown = NULL,
};

#else

static void callback(
    ConstFSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
    char **paths = (char **)eventPaths;

    watchful_stream_t *stream = (watchful_stream_t *)clientCallBackInfo;

    char *prev_path = NULL;
    for (size_t i = 0; i < numEvents; i++) {
        if (watchful_is_excluded(paths[i], stream->wm->excludes)) continue;

        if (prev_path == NULL) {
            prev_path = paths[i];
        } else if (!strcmp(paths[i], prev_path)) {
            prev_path = paths[i];
        } else {
            watchful_event_t *event = (watchful_event_t *)malloc(sizeof(watchful_event_t));

            event->type = 0;
            event->path = watchful_clone_string(prev_path);

            janet_thread_send(stream->parent, janet_wrap_pointer(event), 10);
            prev_path = NULL;
        }
    }

    if (prev_path != NULL) {
        watchful_event_t *event = (watchful_event_t *)malloc(sizeof(watchful_event_t));

        event->type = 0;
        event->path = watchful_clone_string(prev_path);

        janet_thread_send(stream->parent, janet_wrap_pointer(event), 10);
    }
}

static void *loop_runner(void *arg) {
    watchful_stream_t *stream = arg;

    stream->loop = CFRunLoopGetCurrent();

    FSEventStreamScheduleWithRunLoop(
        stream->ref,
        stream->loop,
        kCFRunLoopDefaultMode
    );

    FSEventStreamStart(stream->ref);

    printf("Entering the run loop...\n");
    CFRunLoopRun();
    printf("Leaving the run loop...\n");

    stream->loop = NULL;
    return NULL;
}

static int start_loop(watchful_stream_t *stream) {
    int error = 0;

    pthread_attr_t attr;
    error = pthread_attr_init(&attr);
    if (error) return 1;

    error = pthread_create(&stream->thread, &attr, loop_runner, stream);
    if (error) return 1;

    pthread_attr_destroy(&attr);
    return 0;
}

static int setup(watchful_stream_t *stream) {
    printf("Setting up...\n");

    FSEventStreamContext stream_context;
    memset(&stream_context, 0, sizeof(stream_context));
    stream_context.info = stream;

    CFStringRef path = CFStringCreateWithCString(NULL, (const char *)stream->wm->path, kCFStringEncodingUTF8);
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&path, 1, NULL);

    CFAbsoluteTime latency = stream->delay; /* Latency in seconds */

    stream->ref = FSEventStreamCreate(
        NULL,
        &callback,
        &stream_context,
        pathsToWatch,
        kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
        latency,
        /* kFSEventStreamCreateFlagNone /1* Flags explained in reference *1/ */
        kFSEventStreamCreateFlagFileEvents
    );

    int error = start_loop(stream);
    CFRelease(pathsToWatch);
    CFRelease(path);
    if (error) return 1;

    return 0;
}

static int teardown(watchful_stream_t *stream) {
    printf("Tearing down...\n");

    if (stream->thread) {
        CFRunLoopStop(stream->loop);
        pthread_join(stream->thread, NULL);
    }

    FSEventStreamStop(stream->ref);
    FSEventStreamInvalidate(stream->ref);
    FSEventStreamRelease(stream->ref);

    return 0;
}

watchful_backend_t watchful_fse = {
    .name = "fse",
    .setup = setup,
    .teardown = teardown,
};

#endif
