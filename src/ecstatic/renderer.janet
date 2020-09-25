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


# TODO: Add tests
(defn render-data
  ```
  Render data

  This function uses a bit of a hack to allow for recursive layout calls. After
  rendering the output with `render-fn`, it calls `render-data` again if the
  output has frontmatter. This will occur if the layout used included
  frontmatter.
  ```
  [data site-data render-fn &opt where]
  (let [result      @""
        content     (data :content)
        frontmatter (data :frontmatter)
        args        {:content content :frontmatter frontmatter :site site-data}]
    (with-dyns [:out result]
      (render-fn args))
    (let [result-string (string result)]
      (if (util/has-frontmatter? result-string)
        (let [data        (util/contents->data result-string)
              content     (data :content)
              frontmatter (merge frontmatter (data :frontmatter))
              layout      (or (-?> (frontmatter :layout) keyword) (site-data :default-layout))
              render-fn   (-> (site-data :templates) (get layout))]
          (assert render-fn (string "no render function found for layout " layout))
          (render-data {:content content :frontmatter frontmatter} site-data render-fn))
        result-string))))


(defn render-file
  ```
  Render a file
  ```
  [filepath site-data]
  (let [destination (util/destination filepath (site-data :input-dir) (site-data :output-dir))
        parent-path (util/parent-path destination)]
    (util/mkpath parent-path)
    (if (util/has-frontmatter? (file/open filepath))
      (let [file-data (util/contents->data (slurp filepath) filepath)
            render-fn (temple/create (file-data :content))
            output    (render-data file-data site-data render-fn)]
        (spit destination output))
      (util/copy-file filepath destination))))


(defn render-page
  ```
  Render a page
  ```
  [page site-data]
  (let [content     (markable/markdown->html (page :content))
        frontmatter (page :frontmatter)
        destination (util/destination (frontmatter :permalink) "" (site-data :output-dir))
        layout      (or (-?> (frontmatter :layout) keyword) (site-data :default-layout))
        render-fn   (-> (site-data :templates) (get layout))
        output      (render-data {:content content :frontmatter frontmatter} site-data render-fn)]
    (util/mkpath (util/parent-path destination))
    (spit destination output)))


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
  (render-page post site-data)
  (render-attachments (get-in post [:frontmatter :attachments]) (post :frontmatter) site-data))


(defn render
  ```
  Render the site
  ```
  [site-data]
  (let [output-dir (site-data :output-dir)
        files      (or (site-data :files) [])
        posts      (or (site-data :posts) [])
        pages      (or (site-data :pages) [])]
    (case (os/stat output-dir :mode)
      nil
      (util/mkpath output-dir)

      :directory
      (do
        (util/rimraf output-dir)
        (util/mkpath output-dir))

      (error "output directory is a file"))
    (each file files
      (render-file file site-data))
    (each post posts
      (render-post post site-data))
    (each page pages
      (render-page page site-data))))
