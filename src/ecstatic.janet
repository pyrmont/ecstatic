### Ecstatic

## A static site generator in Janet

## by Michael Camilleri
## 14 September 2020


(import ./ecstatic/utilities :as util)
(import ./ecstatic/loader :as loader)
(import ./ecstatic/generator :as generator)
(import ./ecstatic/renderer :as renderer)


(def- constants
  {:config-file "_config.jdn"
   :layout-dir  "_layouts"
   :posts-dir   "_posts"
   :output-dir  "_site"})


(def- default-config
  {:input-dir            "."
   :output-dir           (constants :output-dir)
   :default-layout       :default
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
   :page-permalink       (fn [& path]
                             (string "/" (string/join path "/") "/index.html"))})


(defn- add-archives
  [site-data]
  (let [archive-pages (generator/generate-archives (site-data :posts) site-data)]
    (array/concat (site-data :pages) archive-pages)
    site-data))


(defn build
  ```
  Build the site
  ```
  []
  (print "Site rendering...")
  (let [config-file   (constants :config-file)
        user-config   (if (nil? (os/stat config-file)) {} (eval-string (slurp config-file)))
        config        (merge default-config user-config)
        input-path    (config :input-dir)
        template-path (util/add-to-path input-path (constants :layout-dir))
        post-path     (util/add-to-path input-path (constants :posts-dir))]
    (assert (= :directory (os/stat input-path :mode)) "input directory does not exist")
    (assert (= :directory (os/stat template-path :mode)) "layout directory does not exist")
    (assert (= :directory (os/stat post-path :mode)) "posts directory does not exist")
    (let [templates (loader/load-templates template-path)
          posts     (loader/load-posts post-path (config :post-permalink))
          files     (loader/load-files input-path)
          site-data (merge config {:templates templates :posts posts :files files :pages @[]})]
      (add-archives site-data)
      (renderer/render site-data)))
  (print "Site rendered"))



(defn main
  ```
  The main function
  ```
  [& args]
  (build))
