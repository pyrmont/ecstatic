(import ./utilities :as util)


(defn make-year-selector
  ```
  Make a selector function for yearly archives

  This returns a function that takes a `post` and `archives` and adds the post
  to the archives under the keys `[:year year]` where `year` is the year of the
  post.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :years])))
    (fn year-selector [post archives]
      (when-let [year (get-in post [:frontmatter :date :year])
                 path [:years (keyword year)]]
        (when [nil? (get-in archives path)]
          (put-in archives path @[]))
        (array/push (get-in archives path) post)))))


(defn make-month-selector
  ```
  Make a selector function for monthly archives

  This returns a function that takes a `post` and `archives` and adds the post
  to the archives under the keys `[:months year month]` where `year` is the year
  of the post and `month` is the month of the post.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :months])))
    (fn month-selector [post archives]
      (when-let [year  (get-in post [:frontmatter :date :year])
                 month (get-in post [:frontmatter :date :month])
                 path  [:months (keyword year "/" month)]]
        (when [nil? (get-in archives path)]
          (put-in archives path @[]))
        (array/push (get-in archives path) post)))))


# TODO: Add tests
(defn make-tag-selector
  ```
  Make a selector function for tag archives

  This returns a function that takes a `post` and `archives` and adds the post
  to the archives under the keys `[:tags tag]` where `tag` is each of the tags
  of the post.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :tags])))
    (let [included     (get-in site-data [:archives :tags :included])
          excluded     (get-in site-data [:archives :tags :excluded])
          is-included? (fn [tag]
                         (cond
                           (and (nil? included) (nil? excluded))
                           true

                           (indexed? included)
                           (util/contains? tag included)

                           (indexed? excluded)
                           (not (util/contains? tag excluded))

                           (error "invalid included or excluded values in config")))]
      (fn tag-selector [post archives]
        (when-let [tags (get-in post [:frontmatter :tags])]
          (each tag tags
            (when (is-included? tag)
              (let [path [:tags (keyword tag)]]
                  (when [nil? (get-in archives path)]
                    (put-in archives path @[]))
                  (array/push (get-in archives path) post)))))))))


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
                  make-tag-selector]
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
  the years archive is not set.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :years])))
    (let [default-config @{:layout "archives"
                           :prefix "archives"
                           :title "Yearly Archives"
                           :permalink-fn (site-data :page-permalink)}
          user-config    (get-in site-data [:archives :years])
          config         (if (dictionary? user-config) (merge default-config user-config) default-config)]
      (make-archiver [:years] config))))


(defn make-month-archiver
  ```
  Make the month archiving function

  This returns the archiver function for the months archive. It returns `nil` if
  the months archive is not set.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :months])))
    (let [default-config @{:layout "archives"
                           :prefix "archives"
                           :title "Monthly Archives"
                           :permalink-fn (site-data :page-permalink)}
          user-config    (get-in site-data [:archives :months])
          config         (if (dictionary? user-config) (merge default-config user-config) default-config)]
      (make-archiver [:months] config))))


(defn make-tag-archiver
  ```
  Make the tag archiving function

  This returns the archiver function for the tags archive. It returns `nil` if
  the tags archive is not set.
  ```
  [site-data]
  (when (not (nil? (get-in site-data [:archives :tags])))
    (let [default-config @{:layout "archives"
                           :prefix "archives"
                           :title "Tag Archives"
                           :permalink-fn (site-data :page-permalink)}
          user-config    (get-in site-data [:archives :tags])
          config         (if (dictionary? user-config) (merge default-config user-config) default-config)]
      (make-archiver [:tags] config))))


(defn make-archivers
  ```
  Make the archiving functions

  This returns an array of archiver functions for the year archives, month
  archives and tag archives. If a particular archive is not set, a function will
  not be made. If no archives are to be generated, returns an empty array.
  ```
  [site-data]
  (let [make-fns [make-year-archiver
                  make-month-archiver
                  make-tag-archiver]
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
        (selector post archives)))
   (reduce (fn [pages archiver]
             (array/concat pages (archiver archives site-data)))
           @[]
           archivers)))
