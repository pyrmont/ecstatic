(import testament :prefix "" :exit true)
(import ../src/ecstatic/grammar :as grammar)


(deftest frontmatter-with-no-frontmatter
  (def expected nil)
  (is (= expected (peg/match grammar/frontmatter "Hello world"))))


(deftest frontmatter-with-frontmatter
  (def expected {:foo "bar"})
  (is (= expected (first (peg/match grammar/frontmatter "---\nfoo: bar\n---\n")))))


(deftest frontmatter-with-duplicate-frontmatter
  (def expected {:foo "bar"})
  (def actual (peg/match grammar/frontmatter "---\nfoo: bar\n---\n---\nfoo: bar\n---\n"))
  (is (one? (length actual)))
  (is (= expected (first actual))))


(deftest page-with-no-frontmatter
  (def expected {:content "Hello world"})
  (is (= expected (struct ;(peg/match grammar/page "Hello world")))))


(deftest page-with-frontmatter-including-string
  (def expected {:frontmatter {:foo "bar"} :content "Hello world"})
  (is (= expected (struct ;(peg/match grammar/page "---\nfoo: bar\n---\nHello world")))))


(deftest page-with-frontmatter-including-booleans-and-numbers
  (def expected {:frontmatter {:foo true :bar 100} :content "Hello world"})
  (is (= expected (struct ;(peg/match grammar/page "---\nfoo: true\nbar: 100\n---\nHello world")))))


(deftest page-with-frontmatter-including-tuple
  (def expected {:frontmatter {:foo [1 false "bar"]} :content "Hello world"})
  (is (= expected (struct ;(peg/match grammar/page "---\nfoo: [1, false, 'bar']\n---\nHello world")))))


(deftest page-with-no-content
  (def expected {:frontmatter {:foo "bar"}})
  (is (= expected (struct ;(peg/match grammar/page "---\nfoo: 'bar'\n---\n")))))


(deftest postname-with-no-date
  (def expected {:slug "foo"})
  (is (= expected (struct ;(peg/match grammar/post-basename "foo")))))


(deftest postname-with-date
  (def expected {:date "2020-01-01" :slug "foo"})
  (is (= expected (struct ;(peg/match grammar/post-basename "2020-01-01-foo")))))


(run-tests!)
