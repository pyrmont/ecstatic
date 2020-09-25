(import ./utilities :as util)


(defn make-year-selector
  ```
  Make a selector function for yearly archives

  This returns a function that takes a post and returns a tuple representing the
  path at which this post will be stored in an associative data structure.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :years])))
    (fn year-selector [post]
      (when-let [year (get-in post [:frontmatter :date :year])]
        [:years year]))))


# TODO: Add tests
(defn make-month-selector
  [site-data]
  nil)


# TODO: Add tests
(defn make-tag-selector
  [site-data]
  nil)


# TODO: Add tests
(defn make-category-selector
  [site-data]
  nil)


(defn make-selectors
  ```
  Make a collection of selector functions

  This returns an array of functions that take a post and returns a tuple
  representing the path at which this post will be stored in an associative data
  structure.
  ```
  [site-data]
  (let [make-fns [make-year-selector
                  make-month-selector
                  make-tag-selector
                  make-category-selector]
        result    @[]]
    (each make-fn make-fns
      (when-let [selector (make-fn site-data)]
        (array/push result selector)))
    result))


(defn make-archiver
  ```
  Make the archiving function

  This returns a function that takes the archive settings and the site data and
  returns an array of pages.
  ```
  [key config]
  (fn archiver [archives site-data]
    (let [archive (get-in archives key)]
      (assert (dictionary? archive) "archives must be a dictionary")
      (reduce (fn [pages [key posts]]
                (array/push pages
                            {:content     ""
                             :frontmatter {:layout    (config :layout)
                                           :posts     posts
                                           :permalink ((config :permalink-fn) (config :prefix) (string key))
                                           :title     (string (config :title) " " key)}}))
              @[]
              (pairs archive)))))


(defn make-year-archiver
  ```
  Make the year archiving function

  This returns the archiver function for the years archive. It returns `nil` if
  the year archives is not set.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :years])))
    (let [default-config @{:layout "archives"
                           :prefix "years"
                           :title "Yearly Archives"
                           :permalink-fn (site-data :page-permalink)}
          user-config    (get-in site-data [:archives :years])
          config         (if (dictionary? user-config) (merge default-config user-config) default-config)]
      (make-archiver [:years] config))))


# TODO: Add tests
(defn make-month-archiver
  [site-data]
  nil)


# TODO: Add tests
(defn make-tag-archiver
  [site-data]
  nil)


# TODO: Add tests
(defn make-category-archiver
  [site-data]
  nil)


(defn make-archivers
  ```
  Make the archiving functions

  This returns an array of archiver functions for the year archives, month
  archives, tag archives and category archives. If a particular archive is not
  set, a function will not be made. If no archives are to be generated, returns
  an empty array.
  ```
  [site-data]
  (let [make-fns [make-year-archiver
                  make-month-archiver
                  make-tag-archiver
                  make-category-archiver]
        result    @[]]
    (each make-fn make-fns
      (when-let [archiver (make-fn site-data)]
        (array/push result archiver)))
    result))


(defn generate-archives
  ```
  Generate archives for the site
  ```
  [posts site-data]
  (assert (indexed? posts) "posts must be an array")
  (let [selectors (make-selectors site-data)
        archivers (make-archivers site-data)
        archives  @{}]
    (each post posts
      (each selector selectors
        (when-let [path (selector post)]
          (when [nil? (get-in archives path)]
            (put-in archives path @[]))
          (array/push (get-in archives path) post))))
   (reduce (fn [pages archiver]
             (array/concat pages (archiver archives site-data)))
           @[]
           archivers)))
