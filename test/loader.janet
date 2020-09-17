(import testament :prefix "" :exit true)
(import ../src/ecstatic/loader :as loader)


(defn- rimraf
  [path]
  (if-let [m (os/stat path :mode)]
    (if (= m :directory)
      (do
        (each subpath (os/dir path) (rimraf (string path "/" subpath)))
        (os/rmdir path))
      (os/rm path))))


(deftest load-templates-with-default-template
  (def expected "<html><body>Hello world</body></html>\n")
  (def template-fns (loader/load-templates "fixtures/templates"))
  (def output @"")
  (with-dyns [:out output] ((template-fns :default) {:content "Hello world"}))
  (is (= [:default] (tuple ;(keys template-fns))))
  (is (= expected (string output))))


(deftest load-templates-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (= {} (loader/load-templates "tmp")))))


(deftest combine-metadata-with-no-from-contents
  (def expected {:date "2020-01-01" :slug "foo"})
  (is (= expected (loader/combine-metadata expected nil))))


(deftest combine-metadata-with-no-conflicts
  (def from-filename {:date "2020-01-01" :slug "foo"})
  (def from-contents {:title "Hello world"})
  (def expected {:date "2020-01-01" :slug "foo" :title "Hello world"})
  (is (= expected (loader/combine-metadata from-filename from-contents))))


(deftest combine-metadata-with-conflicts
  (def from-filename {:date "2020-01-01" :slug "foo"})
  (def from-contents {:date "2020-01-02 12:00:00+0000" :title "Hello world"})
  (def expected {:date "2020-01-02 12:00:00+0000" :slug "foo" :title "Hello world"})
  (is (= expected (loader/combine-metadata from-filename from-contents))))


(deftest load-posts-with-post
  (def expected [{:content "Hello world.\n" :frontmatter {:slug "post" :attachments [] :foo "bar" :path "fixtures/posts/post.md"}}])
  (is (= expected (loader/load-posts "fixtures/posts"))))


(deftest load-posts-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (= [] (loader/load-posts "tmp")))))


(deftest load-files-with-files
  (def expected ["fixtures/files/index.html" "fixtures/files/spacer.gif"])
  (is (= expected (loader/load-files "fixtures/files"))))


(deftest load-files-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (= [] (loader/load-files "tmp")))))


(run-tests!)
