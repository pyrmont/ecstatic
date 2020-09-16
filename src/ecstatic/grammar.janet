(def frontmatter-grammar
  ```
  The grammar for frontmatter
  ```
  ~{
    # Whitespace
    :nl "\n"
    :space (some (set " \t\0\f"))

    # Front matter
    :frontmatter (cmt (* "---" :nl (some (* :variable :nl)) "---" :nl) ,struct)
    :variable (* :key ":" :space :value)
    :key (/ (capture (* :a (any (+ "_" :w)))) ,keyword)
    :value (+ :collection :scalar)

    # Scalars
    :scalar (+ :number :boolean :string :bare)
    :number (/ (capture (* :d+ (? (* "." :d*)))) ,scan-number)
    :boolean (/ (capture (+ "true" "false")) ,eval-string)
    :string (+ :single-string :double-string)
    :single-string (* "'" (capture (any (if-not "'" 1))) "'")
    :double-string (* "\"" (capture (any (if-not "\"" 1))) "\"")
    :bare (capture (some (if-not (set "]}\n") 1)))

    # Collections
    :collection (+ :map :sequence)
    :map (cmt (* "{" :key ":" :s* :value "}") ,struct)
    :sequence (cmt (* "[" :value :s* (any (* "," :s* :value)) "]") ,tuple)})


(def frontmatter
  ```
  Compiled grammar for frontmatter
  ```
  (peg/compile
    (table/to-struct
      (merge frontmatter-grammar ~{:main :frontmatter}))))


(def page
  ```
  Compiled grammar for a page
  ```
  (peg/compile
    (table/to-struct
      (merge frontmatter-grammar
        ~{
          # Content
          :content (capture (some 1))

          :main (* (? (* (constant :frontmatter) :frontmatter)) (? (* (constant :content) :content)))}))))


(def post-basename
  ```
  Compiled grammar for a post's basename
  ```
  (peg/compile
    ~{
      :date (? (* (constant :date) (capture (* (4 :d) "-" (2 :d) "-" (2 :d))) "-"))
      :slug (* (constant :slug) (capture (some 1)))
      :main (* :date :slug)}))


(comment
  (peg/match content "---\ntitle: Hello world\n---\nHello world"))
