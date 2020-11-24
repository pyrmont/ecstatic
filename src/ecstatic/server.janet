(import circlet)


(import ./utilities :as util)


# TODO: Add tests
(defn- respond
  [output-dir rel-path]
  (if (nil? (os/stat (util/add-to-path output-dir rel-path) :mode))
    {:status 404}
    {:kind :static :root "_site"}))


# TODO: Add tests
(defn routes
  [output-dir]
  {:default (fn [req] (respond output-dir (get req :uri)))})


# TODO: Add tests
(defn serve
  ```
  Run the development server
  ```
  [output-dir port ip-address]
  (circlet/server
    (-> (routes output-dir)
        circlet/router
        circlet/logger)
    port
    ip-address))
