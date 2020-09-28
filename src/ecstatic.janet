### Ecstatic

## A static site generator in Janet

## by Michael Camilleri
## 14 September 2020


(import ./ecstatic/builder :as builder)
(import ./ecstatic/server :as server)


(def- constants
  {:config-file "_config.jdn"
   :layout-dir  "_layouts"
   :posts-dir   "_posts"
   :drafts-dir  "_drafts"
   :output-dir  "_site"})


(def- default-config
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
    (server/serve (constants :output-dir))))
