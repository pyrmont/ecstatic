(import testament :prefix "" :exit true)
(import ../src/ecstatic/generator :as generator)


(deftest make-year-selector-with-no-years
  (is (= nil (generator/make-year-selector {}))))


(deftest make-year-selector-with-years
  (def return-type (-> (generator/make-year-selector {:archives {:years true}})
                       type))
  (is (= :function return-type)))


(deftest make-year-selector-with-boolean
  (def selector-fn (generator/make-year-selector {:archives {:years true}}))
  (def post {:frontmatter {:date {:year 2020}}})
  (def expect-archives {:years {:2020 [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-year-selector-with-struct
  (def selector-fn (generator/make-year-selector {:archives {:years {:layout "years"}}}))
  (def post {:frontmatter {:date {:year 2020}}})
  (def expect-archives {:years {:2020 [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-month-selector-with-boolean
  (def selector-fn (generator/make-month-selector {:archives {:months true}}))
  (def post {:frontmatter {:date {:year 2020 :month 1}}})
  (def expect-archives {:months {:2020/1 [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-month-selector-with-struct
  (def selector-fn (generator/make-month-selector {:archives {:months {:layout "months"}}}))
  (def post {:frontmatter {:date {:year 2020 :month 1}}})
  (def expect-archives {:months {:2020/1 [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-tag-selector-with-boolean
  (def selector-fn (generator/make-tag-selector {:archives {:tags true}}))
  (def post {:frontmatter {:tags ["a-tag" "b-tag"]}})
  (def expect-archives {:tags {:a-tag [post] :b-tag [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-tag-selector-with-struct
  (def selector-fn (generator/make-tag-selector {:archives {:tags {:layout "tags" :included ["a-tag"]}}}))
  (def post {:frontmatter {:tags ["a-tag" "b-tag"]}})
  (def expect-archives {:tags {:a-tag [post]}})
  (def actual-archives @{})
  (selector-fn post actual-archives)
  (is (== expect-archives actual-archives)))


(deftest make-selectors-with-no-selectors
  (is (empty? (generator/make-selectors {}))))


(deftest make-selectors-with-selectors-with-booleans
  (def selectors (generator/make-selectors {:archives {:years true}}))
  (def types (map type selectors))
  (is (deep= @[:function] types)))


(deftest make-archiver
  (def site-data {:pages @[]})
  (def post @{:content "Hello world\n" :frontmatter {:date {:year 2020} :title "Foo"}})
  (def archives {:years {:2020 @[post]}})
  (def config {:layout "archives" :prefix "years" :title "Yearly Archives" :permalink-fn (fn [prefix slug] (string "/" prefix "/" slug "/index.html"))})
  (def archiver-fn (generator/make-archiver [:years] config))
  (def actual (archiver-fn archives site-data))
  (def expect @[{:content "" :frontmatter {:layout "archives" :permalink "/years/2020/index.html" :title "Yearly Archives 2020" :posts @[post]}}])
  (is (deep= expect actual)))


(deftest make-year-archiver-with-no-years
  (is (= nil (generator/make-year-archiver {}))))


(deftest make-year-archiver-with-years
  (def return-type (-> (generator/make-year-archiver {:archives {:years true}})
                       type))
  (is (= :function return-type)))


(deftest make-month-archiver-with-no-months
  (is (= nil (generator/make-month-archiver {}))))


(deftest make-month-archiver-with-months
  (def return-type (-> (generator/make-month-archiver {:archives {:months true}})
                       type))
  (is (= :function return-type)))


(deftest make-tag-archiver-with-no-tags
  (is (= nil (generator/make-tag-archiver {}))))


(deftest make-tag-archiver-with-tags
  (def return-type (-> (generator/make-tag-archiver {:archives {:tags true}})
                       type))
  (is (= :function return-type)))


(deftest make-archivers-with-archives
  (def site-data {:archives {:years true}})
  (def actual (map type (generator/make-archivers site-data)))
  (is (deep= @[:function] actual)))


(deftest make-archivers-with-no-archives
  (def site-data {})
  (def actual (generator/make-archivers site-data))
  (is (deep= @[] actual)))


(deftest generate-archives
  (def archives {:years true})
  (def post @{:content "Hello world\n" :frontmatter {:date {:year 2020} :title "Foo"}})
  (def site-data {:archives archives :pages @[] :page-permalink (fn [prefix slug] (string "/" prefix "/" slug "/index.html"))})
  (def actual (generator/generate-archives @[post] site-data))
  (def expect @[{:content "" :frontmatter {:layout "archives" :permalink "/archives/2020/index.html" :title "Yearly Archives 2020" :posts @[post]}}])
  (is (deep= expect actual)))


(run-tests!)
