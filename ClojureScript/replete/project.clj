(defproject replete "0.1.0"
  :dependencies [[andare "0.9.0"]                           ; Update in script/build also
                 [chivorcam "0.3.0"]
                 [cljsjs/parinfer "1.8.1-0"]
                 [com.cognitect/transit-clj "0.8.309"]
                 [com.cognitect/transit-cljs "0.8.248"]
                 [fipp "0.6.8"]
                 [tailrecursion/cljson "1.0.7"]
                 [malabarba/lazy-map "1.3"]
                 [org.clojure/clojure "1.9.0"]
                 [org.clojure/clojurescript "1.10.339"]
                 [org.clojure/test.check "0.10.0-alpha2"]] 
  :clean-targets ["out" "target"]
  :plugins [[lein-cljsbuild "1.1.7"]]
  :cljsbuild {:builds {:test {:source-paths ["src" "test"]
                              :compiler {:output-to "test/resources/compiled.js"
                                         :optimizations :whitespace
                                         :pretty-print true}}}
              :test-commands {"test" ["phantomjs"
                                      "test/resources/test.js"
                                      "test/resources/test.html"]}})
