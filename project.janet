(declare-project
  :name "Ecstatic"
  :description "A static site generator in Janet"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/ecstatic"
  :repo "git+https://github.com/pyrmont/ecstatic"
  :dependencies ["https://github.com/janet-lang/circlet"
                 "https://github.com/pyrmont/markable"
                 "https://github.com/pyrmont/testament"])


(def cflags
  [])


(def platform-cflags
  (case (os/which)
   :macos
   ["-mmacosx-version-min=10.12" "-DMACOS=1" "-framework" "CoreServices" "-Wno-unused-parameter" "-Wno-unused-command-line-argument"]

   :linux
   ["-DLINUX=1" "-pthread" "-Wno-unused-parameter"]

   ["-Wno-unused-parameter"]))


(def lflags
  [])


(def platform-lflags
  [])


(declare-native
  :name    "watchful"
  :cflags  [;default-cflags ;cflags ;platform-cflags]
  :lflags  [;default-lflags ;lflags ;platform-lflags]
  :headers @["src/watchful.h"]
  :source  @["src/watchful/fse.c"
             "src/watchful/inotify.c"
             "src/watchful.c"])


(declare-executable
  :name "ecstatic"
  :entry "src/ecstatic.janet")
