(ns script.bootstrap.build
  (:require [cljs.build.api :as api]))

(println "Building")
(api/build (api/inputs "src")
  {:output-dir         "out"
   :output-to          "out/main.js"
   :optimizations      :none
   :static-fns         true
   :optimize-constants false
   :foreign-libs [{:file "https://raw.githubusercontent.com/shaunlebron/parinfer/1.4.0/lib/parinfer.js"
                   :provides ["parinfer"]}]})
(println "Done building")
(System/exit 0)
