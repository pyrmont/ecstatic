(import ../temple)
(import ./utilities :as util)


(defn load-templates
  ```
  Load the templates
  ```
  [dir]
  (temple/add-loader)
  (let [template-fns @{}]
    (each filename (os/dir dir)
      (let [basename      (util/filename->basename filename)
            render-fns    (require (string dir "/" basename))
            template-name (keyword basename)
            template-fn   (get-in render-fns ['render-dict :value])]
        (put template-fns template-name template-fn)))
    template-fns))


# TODO: Add tests
(defn post-path
  ```
  Determine the path to the post
  ```
  [filepath]
  (case ((os/stat filepath) :mode)
    :file
    filepath

    :directory
    (do
      (var result nil)
      (each name ["index.md" "index.markdown" "index.text" "index.html" "index.htm"]
        (when (not (nil? (os/stat (util/add-to-path filepath name))))
          (set result name)
          (break)))
      (assert (not (nil? result)) "Error: No index file in post directory")
      result)))


# TODO: Add tests
(defn load-attachments
  ```
  Determine the path to any attachments
  ```
  [filepath]
  (case ((os/stat filepath) :mode)
    :file
    @[]

    :directory
    (let [indices ["index.md" "index.markdown" "index.text" "index.htm" "index.html"]]
      (reduce (fn [result filename]
                (if (nil? (find (fn [x] (= filename x)) indices))
                  (array/push result filename)
                  result))
             @[]
             (os/dir filepath)))))


(defn load-posts
  ```
  Load the posts
  ```
  [dir post-permalink-fn]
  (map (fn [filename]
         (let [filepath      (util/add-to-path dir filename)
               post-path     (post-path filepath)
               post-data     (util/contents->data (slurp filepath) filepath)
               basename      (util/filename->basename filename)
               metadata      (merge (util/basename->data basename filepath) (or (post-data :frontmatter) {}))
               permalink     (post-permalink-fn metadata)
               attachments   (load-attachments filepath)
               frontmatter   (merge metadata {:path post-path :permalink permalink :attachments attachments})]
           {:frontmatter frontmatter :content (post-data :content)}))
       (os/dir dir)))


(defn load-files
  ```
  Load the files
  ```
  [dir]
  (let [files @[]]
    (each filename (os/dir dir)
      (when (not (string/has-prefix? "_" filename))
        (let [filepath (string dir "/" filename)]
          (case ((os/stat filepath) :mode)
            :directory
            (let [child-files (load-files filepath)]
              (when (not (empty? child-files))
                (array/push files ;child-files)))

            :file
            (array/push files filepath)))))
    files))


(comment
  (extract-data "Hello")
  (extract-data "---\ntitle: test\n---\nHello")
  (extract-data "---\ntitle: 10\n---\nHello")
  (extract-data "---\ntitle: true\n---\nHello")
  (extract-data "---\ntitle: 'test'\n---\nHello")
  (extract-data "---\ntitle: test\nsubtitle: another test\n---\nHello")
  (extract-data "---\ntitle: test\ncategories: [1, false, 'some-category']\n---\nHello")
  (extract-data "---\ntitle: test\ncategories: {tag: miscellaneous}\n---\nHello")

  (util/filename->basename "hello.world")
  (util/filename->basename "hello.world.txt")

  (load-posts "_posts"))
