(import testament :prefix "" :exit true)
(import ../src/ecstatic/utilities :as util)


(deftest contents->data-with-frontmatter-and-content
  (def expected {:frontmatter {:foo "bar"} :content "Hello world"})
  (is (= expected (util/contents->data "---\nfoo: bar\n---\nHello world"))))


(deftest contents->data-with-empty-string
  (def message "Error: The file contains no data")
  (is (thrown? message (util/contents->data ""))))


(deftest contents->data-with-empty-string-and-location
  (def message "Error: The file foo.bar contains no data")
  (is (thrown? message (util/contents->data "" "foo.bar"))))


(deftest filename->basename-with-one-fullstop
  (is (= "foo" (util/filename->basename "foo.bar"))))


(deftest filename->basename-with-two-fullstops
  (is (= "foo.bar" (util/filename->basename "foo.bar.ext"))))


(deftest has-extension-with-match
  (is (= true (util/has-extension? "ext" "foo.bar.ext"))))


(deftest has-extension-with-no-match
  (is (= false (util/has-extension? "ext" "foo.bar.not-ext"))))


(deftest has-extension-with-matches
  (is (= true (util/has-extension? ["ext" "other-ext"] "foo.bar.ext"))))


(deftest has-extension-with-no-matches
  (is (= false (util/has-extension? ["not-ext" "other-not-ext"] "foo.bar.ext"))))


(deftest has-frontmatter?-with-string-with-no-frontmatter
  (is (= false (util/has-frontmatter? ""))))


(deftest has-frontmatter?-with-string-with-frontmatter
  (is (= true (util/has-frontmatter? "---\n---\n"))))


(deftest has-frontmatter?-with-file-with-no-frontmatter
  (is (= false (util/has-frontmatter? (file/open "fixtures/files/index.html")))))


(deftest has-frontmatter?-with-file-with-frontmatter
  (is (= true (util/has-frontmatter? (file/open "fixtures/posts/post.md")))))


(deftest parent-path-with-no-parent
  (is (= "" (util/parent-path "foo.bar"))))


(deftest parent-path-with-parent
  (is (= "path/to" (util/parent-path "path/to/foo.bar"))))

(run-tests!)
