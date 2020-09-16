(import testament :prefix "" :exit true)
(import ../src/ecstatic/utilities :as util)


(deftest filename-to-basename-with-one-fullstop
  (is (= "foo" (util/filename->basename "foo.bar"))))


(deftest filename-to-basename-with-two-fullstops
  (is (= "foo.bar" (util/filename->basename "foo.bar.ext"))))


(deftest has-extension-with-match
  (is (= true (util/has-extension? "ext" "foo.bar.ext"))))


(deftest has-extension-with-no-match
  (is (= false (util/has-extension? "ext" "foo.bar.not-ext"))))


(deftest has-extension-with-matches
  (is (= true (util/has-extension? ["ext" "other-ext"] "foo.bar.ext"))))


(deftest has-extension-with-no-matches
  (is (= false (util/has-extension? ["not-ext" "other-not-ext"] "foo.bar.ext"))))


(deftest has-frontmatter-with-file-with-no-frontmatter
  (is (= false (util/has-frontmatter? "fixtures/files/index.html"))))


(deftest has-frontmatter-with-file-with-frontmatter
  (is (= true (util/has-frontmatter? "fixtures/posts/post.md"))))


(deftest parent-path-with-no-parent
  (is (= "" (util/parent-path "foo.bar"))))


(deftest parent-path-with-parent
  (is (= "path/to" (util/parent-path "path/to/foo.bar"))))

(run-tests!)
