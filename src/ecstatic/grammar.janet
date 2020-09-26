(defn- month->num
  [month]
  (case month "Jan" 1 "Feb" 2 "Mar" 3 "Apr" 4  "May" 5  "Jun" 6
              "Jul" 7 "Aug" 8 "Sep" 9 "Oct" 10 "Nov" 11 "Jul" 12))


(defn- tz->struct
  [sign hour-key hour mins-key mins]
  (let [hour (case sign "+" hour "-" (* hour -1))]
    {hour-key hour mins-key mins}))


(def datetime-grammar
  ```
  The grammar for date time
  ```
  ~{
    # Whitespace
    :space (some (set " \t\0\f"))

    :datetime (cmt (+ :iso8601ish :rfc822ish) ,struct)

    :iso8601ish (* :year "-" :month-num "-" :day (? (* (+ "T" :space) :time (? :tz))))
    :rfc822ish  (* (? (* :weekday "," :space)) :day :space :month-abr :space :year (? (* :space :time (? (* :space :tz)))))

    :year (* (constant :year) (/ (capture (at-least 1 :d)) ,scan-number))

    :month-num (* (constant :month) (/ (capture (+ (range "19") (* "0" :d) (* "1" (range "02")))) ,scan-number))
    :month-abr (* (constant :month) (cmt (capture (+ "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")) ,month->num))

    :day (* (constant :day) (/ (capture (+ (* "3" (range "01")) (* (range "02") :d) (range "19"))) ,scan-number))

    :weekday (+ "Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")

    :time (* :hour ":" :mins (? (* ":" :secs)))
    :hour (* (constant :hour) (/ (capture (+ (* "2" (range "04")) (* (range "01") :d) :d)) ,scan-number))
    :mins (* (constant :mins) (/ (capture (* (range "05") :d)) ,scan-number))
    :secs (* (constant :secs) (/ (capture (* (range "05") :d)) ,scan-number))

    :tz (* (constant :tz) (cmt (* (capture (set "+-")) :hour (? ":") :mins) ,tz->struct))})


(def datetime
  ```
  Compiled grammar for datetime
  ```
  (peg/compile
    (table/to-struct
      (merge datetime-grammar ~{:main :datetime}))))


(def frontmatter-grammar
  ```
  The grammar for frontmatter
  ```
  ~{
    # Whitespace
    :nl "\n"
    :space (some (set " \t\0\f"))

    # Front matter
    :frontmatter (cmt (* "---" :nl (any (* :variable :nl)) "---" :nl) ,struct)
    :variable (* :key ":" :space :value)
    :key (/ (capture (* :a (any (+ "_" :w)))) ,keyword)
    :value (+ :collection :scalar :bare-value)

    # Scalars
    :scalar (+ :datetime :number :boolean :string)
    :number (/ (capture (* :d+ (? (* "." :d*)))) ,scan-number)
    :boolean (/ (capture (+ "true" "false")) ,eval-string)
    :string (+ :single-string :double-string)
    :single-string (* "'" (capture (any (if-not "'" 1))) "'")
    :double-string (* "\"" (capture (any (if-not "\"" 1))) "\"")

    # Bare values
    :bare-value (capture (some (if-not (set "\n") 1)))
    :bare-item (capture (some (if-not (set ",]}\n") 1)))

    # Collections
    :collection (+ :map :sequence)
    :item (+ :collection :scalar :bare-item)
    :map (cmt (* "{" :key ":" :s* :item "}") ,struct)
    :sequence (cmt (* "[" :s* :item :s* (any (* "," :s* :item :s*)) "]") ,tuple)})


(def frontmatter
  ```
  Compiled grammar for frontmatter
  ```
  (peg/compile
    (table/to-struct
      (merge datetime-grammar frontmatter-grammar ~{:main :frontmatter}))))


(def page
  ```
  Compiled grammar for a page
  ```
  (peg/compile
    (table/to-struct
      (merge datetime-grammar frontmatter-grammar
        ~{
          :content (capture (some 1))
          :main (cmt (* (? (* (constant :frontmatter) :frontmatter)) (? (* (constant :content) :content))) ,struct)}))))


(def post-basename
  ```
  Compiled grammar for a post's basename
  ```
  (peg/compile
    (table/to-struct
      (merge datetime-grammar
        ~{
          :date (? (* (constant :date) :datetime "-"))
          :slug (* (constant :slug) (capture (some 1)))
          :main (cmt (* :date :slug) ,struct)}))))


(comment
  (peg/match content "---\ntitle: Hello world\n---\nHello world"))
