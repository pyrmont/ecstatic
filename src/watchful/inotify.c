#include "../watchful.h"

#ifndef LINUX

watchful_backend_t watchful_inotify = {
    .name = "inotify",
    .setup = NULL,
    .teardown = NULL,
};

#else

static char *path_for_wd(watchful_stream_t *stream, int wd) {
    for(size_t i = 0; i < stream->watch_num; i++) {
        if (wd == stream->watches[i]->wd)
            return (char *)stream->watches[i]->path;
    }

    return NULL;
}

static int handle_event(watchful_stream_t *stream) {
    char buf[4096] __attribute__ ((aligned(__alignof__(struct inotify_event))));
    const struct inotify_event *notify_event;

    if (stream->delay) {
        int seconds = (int)stream->delay;
        int nanoseconds = (int)((stream->delay - seconds) * 100000000);
        struct timespec duration = { .tv_sec = seconds, .tv_nsec = nanoseconds, };
        nanosleep(&duration, NULL);
    }

    int size = read(stream->fd, buf, sizeof(buf));
    if (size <= 0) return 1;

    char *prev_path = NULL;
    for (char *ptr = buf; ptr < buf + size; ptr += sizeof(struct inotify_event) + notify_event->len) {
        notify_event = (const struct inotify_event *)ptr;

        char *path_to_watch = path_for_wd(stream, notify_event->wd);
        if (path_to_watch == NULL) continue;

        char *path = (notify_event->mask & IN_ISDIR) ?
            watchful_clone_string(path_to_watch) :
            watchful_extend_path(path_to_watch, (char *)notify_event->name, 0);

        if (watchful_is_excluded(path, stream->wm->excludes)) {
            free(path);
            continue;
        }

        /* Print event type */
        if (notify_event->mask & IN_MODIFY)
            printf("IN_MODIFY: ");
        if (notify_event->mask & IN_MOVE)
            printf("IN_MOVE: ");
        if (notify_event->mask & IN_ATTRIB)
            printf("IN_ATTRIB: ");
        if (notify_event->mask & IN_DELETE)
            printf("IN_DELETE: ");

        /* Print the name of the file */
        if (notify_event->len)
            printf("%s", notify_event->name);
        else
            printf("%s", stream->wm->path);

        /* Print type of filesystem object */
        if (notify_event->mask & IN_ISDIR)
            printf(" [directory]\n");
        else
            printf(" [file]\n");

        if (prev_path == NULL) {
            prev_path = path;
        } else if (!strcmp(path, prev_path)) {
            free(prev_path);
            prev_path = path;
        } else {
            watchful_event_t *event = (watchful_event_t *)malloc(sizeof(watchful_event_t));

            event->type = 0;
            event->path = prev_path;

            janet_thread_send(stream->parent, janet_wrap_pointer(event), 10);
            prev_path = NULL;
        }
    }

    if (prev_path != NULL) {
        watchful_event_t *event = (watchful_event_t *)malloc(sizeof(watchful_event_t));

        event->type = 0;
        event->path = prev_path;

        janet_thread_send(stream->parent, janet_wrap_pointer(event), 10);
    }

    return 0;
}

static void *loop_runner(void *arg) {
    int error = 0;
    watchful_stream_t *stream = arg;

    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGUSR1);
    error = pthread_sigmask(SIG_BLOCK, &mask, NULL);
    if (error) return NULL;

    int sfd = signalfd(-1, &mask, 0);
    if (sfd == -1) return NULL;

    printf("Entering the run loop...\n");
    while (1) {
        int nfds = ((stream->fd < sfd) ? sfd : stream->fd) + 1;

        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(stream->fd, &readfds);
        FD_SET(sfd, &readfds);

        select(nfds, &readfds, NULL, NULL, NULL);
        if (FD_ISSET(sfd, &readfds)) break;

        printf("Select complete\n");

        error = handle_event(stream);
        if (error) return NULL;

        printf("Read complete\n");
    }
    printf("Leaving the run loop...\n");

    close(sfd);

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

static int add_watches(watchful_stream_t *stream, char *path, DIR *dir) {
    printf("The number of watches is %ld\n", stream->watch_num);
    if (stream->watch_num == 0) {
        stream->watches = (watchful_watch_t **)malloc(sizeof(watchful_watch_t *));
    } else {
        watchful_watch_t **new_watches = (watchful_watch_t **)realloc(stream->watches, sizeof(*stream->watches) * (stream->watch_num + 1));
        if (new_watches == NULL) return 1;
        stream->watches = new_watches;
    }
    watchful_watch_t *watch = (watchful_watch_t *)malloc(sizeof(watchful_watch_t));
    stream->watches[stream->watch_num++] = watch;

    int events = IN_MODIFY | IN_MOVE | IN_ATTRIB | IN_DELETE;

    printf("Adding watch to %s...\n", path);
    watch->wd = inotify_add_watch(stream->fd, path, events);
    if (watch->wd == -1) return 1;
    printf("Watch added\n");

    watch->path = (const uint8_t *)watchful_clone_string(path);

    if (dir == NULL) return 0;

    struct dirent *entry;
    while ((entry = readdir(dir))) {
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;

        char *child_path = watchful_extend_path(path, entry->d_name, 1);

        DIR *dir = opendir(child_path);
        if (dir == NULL) {
            free(child_path);
            continue;
        }

        printf("Adding more watches...\n");
        int error = add_watches(stream, child_path, dir);
        free(child_path);
        closedir(dir);
        if (error) return 1;
    }

    return 0;
}

static int setup(watchful_stream_t *stream) {
    printf("Setting up...\n");
    int error = 0;

    stream->fd = inotify_init();
    if (stream->fd == -1) return 1;

    stream->watch_num = 0;

    char *path = watchful_clone_string((char *)stream->wm->path);
    DIR *dir = opendir(path);
    error = add_watches(stream, path, dir);
    free(path);
    closedir(dir);
    if (error) return 1;

    error = start_loop(stream);
    if (error) return 1;

    return 0;
}

static int teardown(watchful_stream_t *stream) {
    printf("Tearing down...\n");
    int error = 0;

    if (stream->thread) {
        pthread_kill(stream->thread, SIGUSR1);
        pthread_join(stream->thread, NULL);
    }

    for (size_t i = 0; i < stream->watch_num; i++) {
        inotify_rm_watch(stream->fd, stream->watches[i]->wd);
        free((char *)stream->watches[i]->path);
        free(stream->watches[i]);
    }

    free(stream->watches);

    error = close(stream->fd);
    if (error) return 1;

    return 0;
}

watchful_backend_t watchful_inotify = {
    .name = "inotify",
    .setup = setup,
    .teardown = teardown,
};

#endif
