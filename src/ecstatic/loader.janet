(import temple)

(import ./utilities :as util)
(import ./grammar :as grammar)


(defn extract-data
  ```
  Extract the frontmatter and content from a string, `s`
  ```
  [s &opt where]
  (let [location (if (nil? where) "" (string where " "))
        data (peg/match grammar/page s)]
    (assert (not (empty? data)) (string "Error: The file " location "contains no data"))
    (struct ;data)))


(defn load-templates
  ```
  Load the templates
  ```
  [dir]
  (let [template-fns @{}]
    (each filename (os/dir dir)
      (let [template (slurp (string "./" dir "/" filename))
            basename (util/filename->basename filename)]
        (put template-fns (keyword basename) (temple/create template filename))))
    (table/to-struct template-fns)))


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
    []

    :directory
    (let [indices ["index.md" "index.markdown" "index.text" "index.htm" "index.html"]]
      (tuple
        ;(reduce (fn [result filename]
                   (if (nil? (find (fn [x] (= filename x)) indices))
                     (array/push result filename)
                     result))
                @[]
                (os/dir filepath))))))


(defn combine-metadata
  ```
  Combine the metadata from the filename and from the contents
  ```
  [from-filename from-contents]
  (if (nil? from-contents)
    from-filename
    (table/to-struct (merge from-filename from-contents))))


(defn load-posts
  ```
  Load the posts
  ```
  [dir]
  (tuple
    ;(map (fn [filename]
            (let [filepath      (util/add-to-path dir filename)
                  post-path     (post-path filepath)
                  post-data     (extract-data (slurp post-path))
                  basename      (util/filename->basename filename)
                  file-metadata (table :path post-path :attachments (load-attachments filepath) ;(peg/match grammar/post-basename basename))
                  frontmatter   (combine-metadata file-metadata (post-data :frontmatter))]
              {:frontmatter frontmatter :content (post-data :content)}))
          (os/dir dir))))


(defn load-files
  ```
  Load the files
  ```
  [dir]
  (let [files @[]]
    (each filename (os/dir dir)
      (let [filepath (string dir "/" filename)]
        (case ((os/stat filepath) :mode)
          :directory
          (when (not (string/has-prefix? "_" filename))
            (let [child-files (load-files filepath)]
              (when (not (empty? child-files))
                (array/push files ;child-files))))

          :file
          (array/push files filepath))))
    (tuple ;files)))


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
