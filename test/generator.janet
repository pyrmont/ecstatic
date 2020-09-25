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
  (def actual (selector-fn {:frontmatter {:date {:year 2020}}}))
  (is (= [:years 2020] actual)))


(deftest make-year-selector-with-struct
  (def selector-fn (generator/make-year-selector {:archives {:years {:layout "years"}}}))
  (def actual (selector-fn {:frontmatter {:date {:year 2020}}}))
  (is (= [:years 2020] actual)))


(deftest make-selectors-with-no-selectors
  (is (empty? (generator/make-selectors {}))))


(deftest make-selectors-with-selectors-with-booleans
  (def selectors (generator/make-selectors {:archives {:years true}}))
  (def types (map type selectors))
  (is (deep= @[:function] types)))


(deftest make-archiver
  (def site-data {:pages @[]})
  (def post @{:content "Hello world\n" :frontmatter {:date {:year 2020} :title "Foo"}})
  (def archives {:years {2020 @[post]}})
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
  (def expect @[{:content "" :frontmatter {:layout "archives" :permalink "/years/2020/index.html" :title "Yearly Archives 2020" :posts @[post]}}])
  (is (deep= expect actual)))


(run-tests!)
