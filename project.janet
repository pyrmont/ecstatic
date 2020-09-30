(declare-project
  :name "Ecstatic"
  :description "A static site generator in Janet"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/ecstatic"
  :repo "git+https://github.com/pyrmont/ecstatic"
  :dependencies ["https://github.com/janet-lang/circlet"
                 {:repo "https://github.com/pyrmont/juv" :tag "9ce6699c805b1c3a97af0fef23e7453e7b57197a"}
                 "https://github.com/pyrmont/markable"
                 "https://git.sr.ht/~bakpakin/temple"
                 "https://github.com/pyrmont/testament"])


(declare-executable
  :name "ecstatic"
  :entry "src/ecstatic.janet")
