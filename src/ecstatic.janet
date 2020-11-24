### Ecstatic

## A static site generator in Janet

## by Michael Camilleri
## 14 September 2020

(import ../build/watchful)
(import ./ecstatic/builder :as builder)
(import ./ecstatic/server :as server)
(import ./temple)


(def- constants
  {:config-file "_config.janet"
   :layout-dir  "_layouts"
   :posts-dir   "_posts"
   :drafts-dir  "_drafts"
   :output-dir  "_site"})


(def default-config
  {:input-dir            "."
   :output-dir           (constants :output-dir)
   :default-layout       :default
   :page-permalink       (fn [& path]
                             (string "/" (string/join path "/") "/index.html"))
   :post-permalink       (fn [frontmatter]
                           (let [year  (get-in frontmatter [:date :year])
                                 month (get-in frontmatter [:date :month])
                                 day   (get-in frontmatter [:date :day])
                                 slug  (frontmatter :slug)]
                             (string "/" year "/" month "/" day "/" slug "/index.html")))
   :attachment-permalink (fn [attachment frontmatter]
                           (let [year  (get-in frontmatter [:date :year])
                                 month (get-in frontmatter [:date :month])
                                 slug  (frontmatter :slug)]
                             (string "/" year "/" month "/" slug "/" attachment)))
   :draft-permalink      (fn [frontmatter]
                           (let [slug (frontmatter :slug)]
                             (string "/drafts/" slug "/index.html")))})


(defn builder
  [config]
  (builder/build constants config))


(defn watcher
  [config]
  (defn worker [parent]
    (def monitor (watchful/create (config :input-dir) ["4913" "~"]))
    (defn cb [path event-type] (builder/build constants config))
    (watchful/watch monitor cb [:delay 0.5]))
  (thread/new worker 10 :h))


(defn server
  [dir &opt port address]
  (default port 8000)
  (default address "127.0.0.1")
  (server/serve dir port address))


(defn main
  ```
  The main function
  ```
  [& args]

  (when (= 1 (length args))
    (os/exit 1))

  (case (in args 1)
    "build"
    (builder/build constants default-config)

    "serve"
    (let [address (or (args 2) "127.0.0.1")
          port    (or (-?> (args 3) scan-number) 8000)]
      (watcher default-config)
      (server (default-config :output-dir) port address))))
