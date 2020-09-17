(import temple)
(import markable)
(import ./utilities :as util)


(defn render-content
  ```
  Render the content
  ```
  [content args &opt where]
  (let [result    @""
        render-fn (temple/create content where)]
    (with-dyns [:out result]
      (render-fn args))
    result))


(defn render-file
  ```
  Render a file
  ```
  [filepath site-data]
  (let [destination (util/destination filepath (site-data :input-dir) (site-data :output-dir))
        parent-path (util/parent-path destination)]
    (util/mkpath parent-path)
    (if (util/has-frontmatter? filepath)
      (->> (render-content (slurp filepath) {:site-data site-data})
           (spit destination))
      (util/copy-file filepath destination))))


(defn render-attachments
  ```
  Render attachments
  ```
  [attachments frontmatter site-data]
  (when (not (empty? attachments))
    (let [parent-path  (util/parent-path (frontmatter :path))
          permalink-fn (site-data :attachment-permalink)]
      (each attachment attachments
         (let [source      (util/add-to-path parent-path attachment)
               destination (-> (permalink-fn attachment frontmatter)
                               (util/destination "" (site-data :output-dir)))]
           (util/mkpath (util/parent-path destination))
           (util/copy-file source destination))))))


(defn render-post
  ```
  Render a post
  ```
  [post site-data]
  (let [content     (markable/markdown->html (post :content))
        frontmatter (post :frontmatter)
        destination (util/destination ((site-data :post-permalink) frontmatter) "" (site-data :output-dir))
        layout      (keyword (or (frontmatter :layout)) (site-data :post-layout))
        template-fn (-> (get site-data :templates) (get layout))
        output      @""]
    (util/mkpath (util/parent-path destination))
    (assert (function? template-fn) (string "Error: No layout " layout ".html in layout directory"))
    (with-dyns [:out output]
      (template-fn {:content content :frontmatter frontmatter :site-data site-data}))
    (spit destination output)
    (render-attachments (frontmatter :attachments) frontmatter site-data)))


(defn render
  ```
  Render the site
  ```
  [site-data]
  (let [output-dir (site-data :output-dir)
        files      (or (site-data :files) [])
        posts      (or (site-data :posts) [])]
    (case (os/stat output-dir :mode)
      nil
      (util/mkpath output-dir)

      :directory
      (do
        (util/rimraf output-dir)
        (util/mkpath output-dir))

      (error "Error: Output directory is a file"))
    (each file files
      (render-file file site-data))
    (each post posts
      (render-post post site-data))))
