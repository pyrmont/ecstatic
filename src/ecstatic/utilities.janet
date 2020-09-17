(import ./grammar)


# TODO: Add tests
(defn add-to-path
  [path file]
  (if (empty? path)
    file
    (let [path (string/trimr path "/")
          file (string/triml file "/")]
      (string path "/" file))))


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


(defn extract-data
  ```
  Extract the frontmatter and content from a string, `s`
  ```
  [s &opt where]
  (let [location (if (nil? where) "" (string where " "))
        data (peg/match grammar/page s)]
    (assert (not (empty? data)) (string "Error: The file " location "contains no data"))
    (struct ;data)))


(defn filename->basename
  [filename]
  (let [pieces (string/split "." filename)]
    (if (one? (length pieces))
       pieces
       (do
         (array/pop pieces)
         (string/join pieces ".")))))


(defn- has-extension?*
  [candidates ext]
  (if (= (last candidates) ext)
    true
    (if (one? (length candidates))
      false
      (do
        (array/pop candidates)
        (has-extension?* candidates ext)))))


(defn has-extension?
  [ext filename]
  (let [pieces (string/split "." filename)]
    (if (one? (length pieces))
      false
      (if (string? ext)
        (= ext (last pieces))
        (has-extension?* (if (array? ext) ext (array ;ext))
                         (last pieces))))))


(defn has-frontmatter?
  [filepath]
  (let [file (file/open filepath)
        buff @""]
    (defer (file/close file)
      (file/read file 4 buff)
      (if (not (= "---\n" (string buff)))
        false
        (do
          (buffer/clear buff)
          (while (file/read file :line buff)
            (if (= "---\n" (string buff))
               (break)
               (buffer/clear buff)))
          (= "---\n" (string buff)))))))


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
