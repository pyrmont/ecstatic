#include "watchful.h"


/* Utility Functions */

char *watchful_clone_string(char *src) {
    int src_len = strlen(src);
    char *dest = (char *)malloc(sizeof(char) * (src_len + 1));
    if (dest == NULL) return NULL;
    memcpy(dest, src, src_len);
    dest[src_len] = '\0';
    return dest;
}

char *watchful_extend_path(char *path, char *name, int is_dir) {
    int path_len = strlen(path);
    int name_len = strlen(name);
    int new_path_len = path_len + name_len + (is_dir ? 1 : 0);
    char *new_path = (char *)malloc(sizeof(char) * (new_path_len + 1));
    if (new_path == NULL) return NULL;
    memcpy(new_path, path, path_len);
    memcpy(new_path + path_len, name, name_len);
    if (is_dir) new_path[new_path_len - 1] = '/';
    new_path[new_path_len] = '\0';
    return new_path;
}

int watchful_is_excluded(char *path, JanetView excludes) {
    if (excludes.len == 0) return 0;
    int path_len = strlen(path);
    for (size_t i = 0; i < (size_t)excludes.len; i++) {
        const uint8_t *exclude = janet_getstring(excludes.items, i);
        int exclude_len = strlen((char *)exclude);
        if (exclude_len > path_len) continue;
        for (int p = path_len - 1, e = exclude_len - 1; p >= 0 && e >= 0; p--, e--) {
            if (path[p] != exclude[e]) break;
            if (e == 0 && p == 0) return 1;
            if (e == 0 && exclude[e] != '/') return 1;
        }
    }
    return 0;
}

/* Deinitialising */

static int watchful_monitor_gc(void *p, size_t size) {
    (void) size;
    watchful_monitor_t *monitor = (watchful_monitor_t *)p;
    if (monitor->path != NULL) {
        free((uint8_t *)monitor->path);
        monitor->path = NULL;
    }
    return 0;
}

/* Marking */

static int watchful_monitor_mark(void *p, size_t size) {
    (void) size;
    watchful_monitor_t *monitor = (watchful_monitor_t *)p;

    Janet wrapped_path = janet_wrap_string(monitor->path);
    janet_mark(wrapped_path);

    for (size_t i = 0; i < (size_t)monitor->excludes.len; i++) {
        Janet item = monitor->excludes.items[i];
        janet_mark(item);
    }
    return 0;
}

/* Type Definition */

static const JanetAbstractType watchful_monitor_type = {
    "watchful/monitor",
    watchful_monitor_gc,
    watchful_monitor_mark,
    JANET_ATEND_GCMARK
};

/* C Functions */

static int watchful_copy_path(watchful_monitor_t *wm, const uint8_t *path, size_t max_len) {
    size_t path_len = strlen((char *)path);

    if (path_len > max_len) return 1;

    char *buf = (char *)malloc(sizeof(char) * max_len);
    size_t buf_len = 0;

    if (path[0] == '/') {
        memcpy(buf, path, path_len);
        if (path[path_len - 1] == '/') path_len--;
    } else {
        getcwd(buf, max_len);
        size_t cwd_len = strlen(buf);
        buf[cwd_len] = '/';
        buf_len = cwd_len + 1;
        memcpy(buf + buf_len, path, path_len);
    }

    if (buf_len + path_len + 2 > max_len) {
        free(buf);
        return 1;
    }

    buf[buf_len + path_len] = '/';
    buf[buf_len + path_len + 1] = '\0';
    printf("The path being watched is %s\n", buf);

    wm->path = (const uint8_t *)buf;
    return 0;
}

static JanetThread *watchful_current_thread() {
    JanetCFunction cfun = janet_unwrap_cfunction(janet_resolve_core("thread/current"));
    return (JanetThread *)janet_unwrap_abstract(cfun(0, NULL));
}

static double watchful_option_number(JanetTuple head, char *name, double dflt) {
    size_t head_size = (head == NULL) ? 0 : janet_tuple_length(head);

    for (size_t i = 0; i < head_size; i += 2) {
        if (!janet_cstrcmp(janet_getkeyword(head, i), name))
            return janet_getnumber(head, i + 1);
    }

    return dflt;
}

static Janet cfun_create(int32_t argc, Janet *argv) {
    janet_arity(argc, 1, 3);

    const uint8_t *path = janet_getstring(argv, 0);

    JanetView excludes;
    if (argc >= 2) {
        excludes = janet_getindexed(argv, 1);
    } else {
        excludes.items = NULL;
        excludes.len = 0;
    }

    /* Need to know backend first */
    watchful_backend_t *backend = NULL;
    if (argc == 3) {
        const uint8_t *choice = janet_getkeyword(argv, 2);
        if (!janet_cstrcmp(choice, "fse")) {
            backend = &watchful_fse;
        } else if (!janet_cstrcmp(choice, "inotify")) {
            backend = &watchful_inotify;
        } else {
            janet_panicf("backend :%s not found", choice);
        }
    } else {
        backend = &watchful_default_backend;
    }

    if (backend->setup == NULL || backend->teardown == NULL) {
        janet_panicf("backend :%s is not supported on this platform", backend->name);
    }

    watchful_monitor_t *wm = (watchful_monitor_t *)janet_abstract(&watchful_monitor_type, sizeof(watchful_monitor_t));
    wm->backend = backend;
    wm->path = NULL;
    wm->excludes = excludes;

    int error = watchful_copy_path(wm, path, 1024);
    if (error) janet_panic("path too long");

    return janet_wrap_abstract(wm);
}

static Janet cfun_watch(int32_t argc, Janet *argv) {
    janet_arity(argc, 2, 3);

    watchful_monitor_t *wm = (watchful_monitor_t *)janet_getabstract(argv, 0, &watchful_monitor_type);
    JanetFunction *cb = janet_getfunction(argv, 1);
    JanetTuple head = (argc == 3) ? janet_gettuple(argv, 2) : NULL;

    if (argc == 3 && janet_tuple_length(head) % 2 != 0) janet_panicf("missing option value");

    double count = watchful_option_number(head, "count", INFINITY);
    double elapse = watchful_option_number(head, "elapse", INFINITY);
    double delay = watchful_option_number(head, "delay", 0.0);

    watchful_stream_t *stream = (watchful_stream_t *)malloc(sizeof(watchful_stream_t));
    stream->wm = wm;
    stream->parent = watchful_current_thread();
    stream->delay = delay;

    wm->backend->setup(stream);
    printf("Setup complete\n");

    double counted = 0.0;
    double elapsed = 0.0;
    time_t start = time(0);
    while (counted < count && elapsed < elapse) {
        double timeout = (elapse == INFINITY) ? INFINITY : elapse;
        Janet out;
        int timed_out = janet_thread_receive(&out, timeout);
        if (!timed_out) {
            watchful_event_t *event = (watchful_event_t *)janet_unwrap_pointer(out);
            Janet tup[2] = {janet_cstringv(event->path), janet_wrap_integer(event->type)};
            JanetTuple args = janet_tuple_n(tup, 2);
            JanetFiber *cb_f = janet_fiber(cb, 64, 2, args);
            cb_f->env = (janet_current_fiber())->env;
            JanetSignal sig = janet_continue(cb_f, janet_wrap_nil(), &out);
            if (sig != JANET_SIGNAL_OK && sig != JANET_SIGNAL_YIELD) {
                janet_stacktrace(cb_f, out);
                janet_printf("top level signal(%d): %v\n", sig, out);
            }
            free(event->path);
            free(event);
        }
        counted++;
        time_t now = time(0);
        elapsed = (double)now - (double)start;
    }

    wm->backend->teardown(stream);
    printf("Teardown complete\n");

    stream->wm = NULL;
    stream->parent = NULL;
    free(stream);

    return janet_wrap_integer(0);
}

static const JanetReg cfuns[] = {
    {"create", cfun_create,
     "(watchful/create path &opt excludes backend)\n\n"
     "Create a monitor for `path`\n\n"
     "The monitor can optionally be created with `excludes`, an array or tuple "
     "of strings that are paths that the monitor will exclude, and `backend`, "
     "a keyword representing the API that the monitor will use (`:fse`, "
     "`:inotify`). If a backend is selected that is not supported, the function "
     "will panic."
    },
    {"watch", cfun_watch,
     "(watchful/watch [monitor & options] cb)\n\n"
     "Watch `monitor` and execute the function `cb` on changes\n\n"
     "The watch can optionally include `:count <integer>` and/or `:elapse "
     "<double>`. The integer after `:count` is the number of changes that "
     "should be monitored before the watch terminates. The double after "
     "`:elapse` is the number of seconds to wait until the watch terminates."
    },
    {NULL, NULL, NULL}
};

void watchful_register_watcher(JanetTable *env) {
    janet_cfuns(env, "watchful", cfuns);
}

JANET_MODULE_ENTRY(JanetTable *env) {
    watchful_register_watcher(env);
}
