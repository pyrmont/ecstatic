(import testament :prefix "" :exit true)
(import ../src/ecstatic/grammar :as grammar)


(deftest datetime-with-iso8601-date-but-no-time
  (def expected [{:year 2020 :month 1 :day 1}])
  (is (== expected (peg/match grammar/datetime "2020-01-01"))))


(deftest datetime-with-iso8601-date-but-no-timezone
  (def expected [{:year 2020 :month 1 :day 1 :hour 12 :mins 0 :secs 0}])
  (is (== expected (peg/match grammar/datetime "2020-01-01T12:00:00"))))


(deftest datetime-with-iso8601-date
  (def expected [{:year 2020 :month 1 :day 1 :hour 12 :mins 0 :secs 0 :tz {:hour 9 :mins 0}}])
  (is (== expected (peg/match grammar/datetime "2020-01-01T12:00:00+0900"))))


(deftest datetime-with-rfc822-but-no-weekday-or-time
  (def expected [{:year 2020 :month 1 :day 1}])
  (is (== expected (peg/match grammar/datetime "1 Jan 2020"))))


(deftest datetime-with-rfc822-but-no-time
  (def expected [{:year 2020 :month 1 :day 1}])
  (is (== expected (peg/match grammar/datetime "Wed, 1 Jan 2020"))))


(deftest datetime-with-rfc822-but-no-seconds
  (def expected [{:year 2020 :month 1 :day 1 :hour 12 :mins 0}])
  (is (== expected (peg/match grammar/datetime "Wed, 1 Jan 2020 12:00"))))


(deftest datetime-with-rfc822
  (def expected [{:year 2020 :month 1 :day 1 :hour 12 :mins 0 :secs 0 :tz {:hour -9 :mins 0}}])
  (is (== expected (peg/match grammar/datetime "Wed, 1 Jan 2020 12:00:00 -0900"))))


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
  (def expected [{:content "Hello world"}])
  (is (== expected (peg/match grammar/page "Hello world"))))


(deftest page-with-empty-frontmatter
  (def expected [{:content "Hello world" :frontmatter {}}])
  (is (== expected (peg/match grammar/page "---\n---\nHello world"))))


(deftest page-with-frontmatter-including-string
  (def expected [{:frontmatter {:foo "bar"} :content "Hello world"}])
  (is (== expected (peg/match grammar/page "---\nfoo: bar\n---\nHello world"))))


(deftest page-with-frontmatter-including-booleans-and-numbers
  (def expected [{:frontmatter {:foo true :bar 100} :content "Hello world"}])
  (is (== expected (peg/match grammar/page "---\nfoo: true\nbar: 100\n---\nHello world"))))


(deftest page-with-frontmatter-including-tuple
  (def expected [{:frontmatter {:foo [1 false "bar"]} :content "Hello world"}])
  (is (== expected (peg/match grammar/page "---\nfoo: [1, false, 'bar']\n---\nHello world"))))


(deftest page-with-no-content
  (def expected [{:frontmatter {:foo "bar"}}])
  (is (== expected (peg/match grammar/page "---\nfoo: 'bar'\n---\n"))))


(deftest postname-with-no-date
  (def expected [{:slug "foo"}])
  (is (== expected (peg/match grammar/post-basename "foo"))))


(deftest postname-with-date
  (def expected [{:date {:year 2020 :month 1 :day 1} :slug "foo"}])
  (is (== expected (peg/match grammar/post-basename "2020-01-01-foo"))))


(run-tests!)
