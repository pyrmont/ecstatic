(import ./grammar)


# TODO: Add tests
(defn add-to-path
  [path file]
  (if (empty? path)
    file
    (let [path (string/trimr path "/")
          file (string/triml file "/")]
      (string path "/" file))))


# TODO: Add tests
(defn basename->data
  [basename &opt where]
  (let [location (if (nil? where) "" (string where " "))
        data     (peg/match grammar/post-basename basename)
        result   (if (nil? data) nil (array/pop data))]
    (assert (and (not (nil? result)) (not (empty? result))) (string "Error: The basename " basename "contains no data"))
    result))


(defn contents->data
  ```
  Convert contents to structured data
  ```
  [contents &opt where]
  (let [location (if (nil? where) "" (string where " "))
        data     (peg/match grammar/page contents)
        result   (if (nil? data) nil (array/pop data))]
    (assert (and (not (nil? result)) (not (empty? result))) (string "Error: The file " location "contains no data"))
    result))


# TODO: Add tests
(defn copy-file
  [source dest]
  (spit dest (slurp source)))


# TODO: Add tests
(defn destination
  [filepath input-dir output-dir]
  (if (empty? input-dir)
    (add-to-path output-dir filepath)
    (->>
      (string/replace input-dir "" filepath)
      (add-to-path output-dir))))


(defn filename->basename
  ```
  Convert a filename to a basename
  ```
  [filename]
  (let [pieces (string/split "." filename)]
    (if (one? (length pieces))
       pieces
       (do
         (array/pop pieces)
         (string/join pieces ".")))))


(defn has-extension?
  ```
  Check whether `filename` ends in `ext-or-exts`
  ```
  [ext-or-exts filename]
  (if (string? ext-or-exts)
    (string/has-suffix? (string "." ext-or-exts) filename)
    (not (not (some (fn [ext] (string/has-suffix? (string "." ext) filename)) ext-or-exts)))))


(defn has-frontmatter?
  ```
  Check whether `source` has frontmatter

  The type of `source` can be either a string or an open file descriptor. If
  it's the latter, the function will close the descriptor before returning.
  ```
  [source]
  (case (type source)
    :string
    (not (nil? (peg/match grammar/frontmatter source)))

    :core/file
    (let [buff @""]
      (defer (file/close source)
        (file/read source 4 buff)
        (when (not (= "---\n" (string buff)))
          (break false))
        (buffer/clear buff)
        (while (file/read source :line buff)
          (if (= "---\n" (string buff))
             (break))
          (buffer/clear buff))
        (= "---\n" (string buff))))

    (error "invalid source")))


# TODO: Add tests
(defn mkpath
  [dirpath]
  (when (not (empty? dirpath))
    (let [path @""]
      (each dir (string/split "/" dirpath)
        (if (not (empty? path))
          (buffer/push-string path "/"))
        (buffer/push-string path dir)
        (os/mkdir (string path))))))


(defn parent-path
  ```
  Return the path to the parent directory of the file at `filepath`
  ```
  [filepath]
  (let [pieces (string/split "/" filepath)]
    (if (one? (length pieces))
       ""
       (do
         (array/pop pieces)
         (string/join pieces "/")))))


# TODO: Add tests
(defn rimraf
  [path]
  (if-let [m (os/stat path :mode)]
    (if (= m :directory)
      (do
        (each subpath (os/dir path) (rimraf (string path "/" subpath)))
        (os/rmdir path))
      (os/rm path))))
