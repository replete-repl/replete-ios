(defproject replete "0.1.0"
  :dependencies [[org.clojure/clojure "1.7.0"]
                 [org.clojure/clojurescript "0.0-3459"]
                 [org.clojure/tools.reader "0.10.0-SNAPSHOT" :exclusions [org.clojure/clojure]]
                 [com.cognitect/transit-cljs "0.8.220"]
                 [com.cognitect/transit-clj "0.8.275"]]
  :clean-targets ["out" "target"])
