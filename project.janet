(declare-project
  :name "Ecstatic"
  :description "A static site generator in Janet"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/ecstatic"
  :repo "git+https://github.com/pyrmont/ecstatic"
  :dependencies ["https://github.com/pyrmont/markable"
                 "https://git.sr.ht/~bakpakin/temple"
                 "https://github.com/pyrmont/testament"])


(declare-executable
  :name "ecstatic"
  :entry "src/ecstatic.janet")
