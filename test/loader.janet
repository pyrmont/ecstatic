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
  (is (deep= @[:default] (keys template-fns)))
  (is (= expected (string output))))


(deftest load-templates-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (deep= @{} (loader/load-templates "tmp")))))


(deftest load-posts-with-post
  (def expected @[{:content "Hello world.\n" :frontmatter @{:slug "post" :attachments @[] :foo "bar" :path "fixtures/posts/post.md" :permalink "post.html"}}])
  (is (deep= expected (loader/load-posts "fixtures/posts" (fn [x] "post.html")))))


(deftest load-posts-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (deep= @[] (loader/load-posts "tmp" (fn [x] ""))))))


(deftest load-files-with-files
  (def expected @["fixtures/files/index.html" "fixtures/files/spacer.gif"])
  (def actual (sorted (loader/load-files "fixtures/files")))
  (is (deep= expected actual)))


(deftest load-files-with-empty-directory
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (is (deep= @[] (loader/load-files "tmp")))))


(run-tests!)
