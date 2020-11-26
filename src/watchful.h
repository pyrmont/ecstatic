#ifndef WATCHER_H
#define WATCHER_H

#ifdef LINUX
#define INOTIFY
#endif

#ifdef MACOS
#define FSE
#endif

/* General */
#include <string.h>
#include <time.h>
#include "watchful/wildmatch.h"

/* POSIX */
#include <pthread.h>

#ifdef INOTIFY
#include <dirent.h>
#include <signal.h>
#include <unistd.h>
#include <sys/inotify.h>
#include <sys/select.h>
#include <sys/signalfd.h>
#include <sys/stat.h>
#include <sys/types.h>
#endif

#ifdef FSE
#include <CoreServices/CoreServices.h>
#endif

/* Janet */
#include <janet.h>

/* Type Aliases */

typedef pthread_t watchful_thread_t;

/* Forward Declarations */

struct watchful_monitor_t;
struct watchful_backend_t;
struct watchful_stream_t;
struct watchful_watch_t;

/* Types */

typedef struct watchful_backend_t {
  const char *name;
  int (*setup)(struct watchful_stream_t *stream);
  int (*teardown)(struct watchful_stream_t *stream);
} watchful_backend_t;

typedef struct watchful_excludes_t {
  char **paths;
  size_t len;
} watchful_excludes_t;

typedef struct watchful_monitor_t {
  struct watchful_backend_t *backend;
  const uint8_t *path;
  watchful_excludes_t *excludes;
} watchful_monitor_t;

typedef struct watchful_stream_t {
  struct watchful_monitor_t *wm;
  watchful_thread_t thread;
  JanetThread *parent;
  double delay;

#ifdef INOTIFY
  int fd;
  size_t watch_num;
  struct watchful_watch_t **watches;
#endif

#ifdef FSE
  FSEventStreamRef ref;
  CFRunLoopRef loop;
#endif
} watchful_stream_t;

typedef struct watchful_watch_t {
#ifdef INOTIFY
  int wd;
  const uint8_t *path;
#endif
} watchful_watch_t;

typedef struct watchful_event_t {
  int type;
  char *path;
} watchful_event_t;

/* Externs */

extern watchful_backend_t watchful_fse;
extern watchful_backend_t watchful_inotify;

#ifdef LINUX
#define watchful_default_backend watchful_inotify
#elif MACOS
#define watchful_default_backend watchful_fse
#endif

/* Utility Functions */
char *watchful_clone_string(char *src);
char *watchful_extend_path(char *path, char *name, int is_dir);
int watchful_is_excluded(char *path, watchful_excludes_t *excludes);

#endif
