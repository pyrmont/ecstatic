(declare-project
  :name "Statically"
  :description "A static site generator in Janet"
  :author "Michael Camilleri"
  :license "MIT"
  :url "https://github.com/pyrmont/statically"
  :repo "git+https://github.com/pyrmont/statically"
  :dependencies ["https://github.com/pyrmont/markable"
                 "https://git.sr.ht/~bakpakin/temple"
                 "https://github.com/pyrmont/testament"])

# (declare-source
#   :source ["src/ecstatic/builder.janet"
#            "src/ecstatic/utilities.janet"])


(declare-executable
  :name "ecstatic"
  :entry "src/ecstatic.janet")
