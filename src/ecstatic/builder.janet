(import ./utilities :as util)
(import ./loader :as loader)
(import ./generator :as generator)
(import ./renderer :as renderer)


(defn- add-archives
  [site-data]
  (when-let [archive-pages (generator/generate-archives (site-data :posts) site-data)]
    (array/concat (site-data :pages) archive-pages)
    site-data))


(defn build
  ```
  Build the site
  ```
  [constants default-config]
  (print "Site rendering...")
  (let [config-file   (constants :config-file)
        user-config   (if (nil? (os/stat config-file)) {} (eval-string (slurp config-file)))
        config        (merge default-config user-config)
        input-path    (config :input-dir)
        template-path (util/add-to-path input-path (constants :layout-dir))
        post-path     (util/add-to-path input-path (constants :posts-dir))
        drafts-path   (util/add-to-path input-path (constants :drafts-dir))]
    (assert (util/dir-exists? input-path) "input directory does not exist")
    (assert (util/dir-exists? template-path) "layout directory does not exist")
    (assert (util/dir-exists? post-path) "posts directory does not exist")
    (let [templates (loader/load-templates template-path)
          files     (loader/load-files input-path)
          posts     (loader/load-posts post-path (config :post-permalink))
          drafts    (if (util/dir-exists? drafts-path) (loader/load-posts drafts-path (config :draft-permalink)) @[])
          site-data (merge config {:templates templates :files files :pages @[] :posts posts :drafts drafts})]
      (add-archives site-data)
      (renderer/render site-data)))
  (print "Site rendered"))
