(defproject replete "0.1.0"
  :dependencies [[org.clojure/clojure "1.7.0"]
                 [org.clojure/clojurescript "1.7.170"]
                 [tailrecursion/cljson "1.0.7"]
                 [parinfer "0.2.0"]]
  :clean-targets ["out" "target"]
  :plugins [[lein-cljsbuild "1.1.1"]]
  :cljsbuild {:builds {:test {:source-paths ["src" "test"]
                              :compiler {:output-to "test/resources/compiled.js"
                                         :optimizations :whitespace
                                         :pretty-print true}}}
              :test-commands {"test" ["phantomjs"
                                      "test/resources/test.js"
                                      "test/resources/test.html"]}})
