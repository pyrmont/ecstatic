(import testament :prefix "" :exit true)
(import ../src/ecstatic/renderer :as renderer)


(defn- rimraf
  [path]
  (if-let [m (os/stat path :mode)]
    (if (= m :directory)
      (do
        (each subpath (os/dir path) (rimraf (string path "/" subpath)))
        (os/rmdir path))
      (os/rm path))))


(deftest render-file-with-text-file
  (os/mkdir "tmp")
  (def site-data {:input-dir "fixtures/files" :output-dir "tmp"})
  (defer (rimraf "tmp")
    (renderer/render-file "fixtures/files/index.html" site-data)
    (def expected-list ["index.html"])
    (def actual-list (tuple ;(os/dir "tmp")))
    (is (= expected-list actual-list))
    (def expected-contents "<html><body>Hello world</body></html>\n")
    (def actual-contents (string (slurp (string "tmp/" (first (os/dir "tmp"))))))
    (is (= expected-contents actual-contents))))


(deftest render-file-with-image-file
  (os/mkdir "tmp")
  (def site-data {:input-dir "fixtures/files" :output-dir "tmp"})
  (defer (rimraf "tmp")
    (renderer/render-file "fixtures/files/spacer.gif" site-data)
    (def expected-list ["spacer.gif"])
    (def actual-list (tuple ;(os/dir "tmp")))
    (is (= expected-list actual-list))))


(deftest render-attachments-with-empty-list
  (os/mkdir "tmp")
  (defer (rimraf "tmp")
    (renderer/render-attachments [] {} {})
    (def expected-list [])
    (def actual-list (tuple ;(os/dir "tmp")))
    (is (= expected-list actual-list))))


(deftest render-attachments-with-non-empty-list
  (os/mkdir "tmp")
  (def site-data {:output-dir "tmp"
                  :attachment-permalink (fn [attachment frontmatter]
                                          (string (string/slice (frontmatter :date) 0 4) "/" (frontmatter :slug) "/" attachment))})
  (def frontmatter {:path "fixtures/files/index.html" :date "2020-01-01" :slug "post"})
  (defer (rimraf "tmp")
    (renderer/render-attachments ["spacer.gif"] frontmatter site-data)
    (def expected :file)
    (def actual (os/stat "tmp/2020/post/spacer.gif" :mode))
    (is (= expected actual))))


(deftest render-with-blocking-file
  (spit "tmp" "Hello world\n")
  (def site-data {:output-dir "tmp"})
  (def message "Error: Output directory is a file")
  (defer (rimraf "tmp")
    (is (thrown? message (renderer/render site-data)))))


(deftest render-with-empty-directory
  (os/mkdir "tmp")
  (def site-data {:input-dir "fixtures/files"
                  :output-dir "tmp"
                  :post-layout :default
                  :post-permalink (fn [frontmatter]
                                    (string (string/slice (frontmatter :date) 0 4) "/" (frontmatter :slug) ".html"))
                  :templates {:default (fn [args] (print (args :content)))}
                  :files ["fixtures/files/index.html"]
                  :posts [{:content "Hello world.\n"
                           :frontmatter {:path "fixtures/files/_posts/post.md" :attachments [] :slug "post" :date "2020-01-01"}}]})
  (defer (rimraf "tmp")
    (renderer/render site-data)
    (is (= ["index.html" (tuple ;(os/dir "tmp"))]))))


(run-tests!)
