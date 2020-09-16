### Ecstatic

## A static site generator in Janet

## by Michael Camilleri
## 14 September 2020


(import ./ecstatic/utilities :as util)
(import ./ecstatic/loader :as loader)
(import ./ecstatic/renderer :as renderer)


(def- default-config
  {:input-dir            "."
   :output-dir           "_site"
   :post-layout          :default
   :post-permalink       (fn [frontmatter]
                           (let [year  (string/slice (frontmatter :date) 0 4)
                                 month (string/slice (frontmatter :date) 5 7)
                                 slug  (frontmatter :slug)]
                             (string year "/" month "/" slug "/index.html")))
   :attachment-permalink (fn [attachment frontmatter]
                           (let [year  (string/slice (frontmatter :date) 0 4)
                                 month (string/slice (frontmatter :date) 5 7)
                                 slug  (frontmatter :slug)]
                             (string year "/" month "/" slug "/" attachment)))})


(defn build
  ```
  Build the site
  ```
  []
  (print "Site rendering...")
  (let [config-file   "_config.jdn"
        config        (if (nil? (os/stat config-file)) {} (eval-string (slurp config-file)))
        input-path    (or (config :input-dir) (default-config :input-dir))
        template-path (util/add-to-path input-path "_layouts")
        post-path     (util/add-to-path input-path "_posts")]
    (assert (= :directory (os/stat input-path :mode)) "Error: Input directory does not exist")
    (assert (= :directory (os/stat template-path :mode)) "Error: Layout directory does not exist")
    (assert (= :directory (os/stat post-path :mode)) "Error: Posts directory does not exist")
    (let [templates (loader/load-templates template-path)
          posts     (loader/load-posts post-path)
          files     (loader/load-files input-path)
          site-data (table/to-struct (merge default-config config {:templates templates :posts posts :files files}))]
      (renderer/render site-data)))
  (print "Site rendered"))



(defn main
  ```
  The main function
  ```
  [& args]
  (build))
