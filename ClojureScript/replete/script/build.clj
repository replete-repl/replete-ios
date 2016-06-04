(ns script.bootstrap.build
  (:require [clojure.java.io :as io]
    [cljs.build.api :as api]
    [cljs.analyzer]
    [cognitect.transit :as transit])
  (:import [java.io ByteArrayOutputStream]))

(defn write-cache [cache out-path]
  (let [out (ByteArrayOutputStream. 1000000)
        writer (transit/writer out :json)]
    (transit/write writer cache)
    (spit (io/file out-path) (.toString out))))

(defn extract-analysis-cache [res out-path]
  (let [cache (read-string (slurp res))]
    (write-cache cache out-path)))

(println "Building")
(api/build (api/inputs "src")
  {:output-dir         "out"
   :output-to          "out/main.js"
   :optimizations      :none
   :static-fns         true
   :optimize-constants false
   :dump-core          false})
(println "Done building")

(defn copy-source
  [path]
  (spit (str "out/" path)
    (slurp (io/resource path))))

(copy-source "cljs/test.cljc")
(copy-source "cljs/spec.cljc")
(copy-source "cljs/spec/impl/gen.cljc")
(copy-source "cljs/analyzer/api.cljc")
(copy-source "clojure/template.clj")
(copy-source "cljs/core/async/macros.cljc")
(copy-source "cljs/core/async/impl/ioc_macros.clj")

(let [res (io/resource "cljs/core.cljs.cache.aot.edn")
      cache (read-string (slurp res))]
  (doseq [key (keys cache)]
    (write-cache (key cache) (str "out/cljs/core.cljs.cache.aot." (munge key) ".json"))))

(let [res "out/cljs/core$macros.cljc.cache.edn"
      cache (read-string (slurp res))]
  (doseq [key (keys cache)]
    (write-cache (key cache) (str "out/cljs/core$macros.cljc.cache." (munge key) ".json"))))

(extract-analysis-cache "out/clojure/set.cljs.cache.edn" "out/clojure/set.cljs.cache.json")
(extract-analysis-cache "out/clojure/string.cljs.cache.edn" "out/clojure/string.cljs.cache.json")
(extract-analysis-cache "out/clojure/data.cljs.cache.edn" "out/clojure/data.cljs.cache.json")
(extract-analysis-cache "out/clojure/walk.cljs.cache.edn" "out/clojure/walk.cljs.cache.json")
(extract-analysis-cache "out/clojure/zip.cljs.cache.edn" "out/clojure/zip.cljs.cache.json")
(extract-analysis-cache "out/clojure/core/reducers.cljs.cache.edn" "out/clojure/core/reducers.cljs.cache.json")

(extract-analysis-cache "out/cljs/analyzer.cljc.cache.edn" "out/cljs/analyzer.cljc.cache.json")
(extract-analysis-cache "out/cljs/analyzer/api.cljc.cache.edn" "out/cljs/analyzer/api.cljc.cache.json")
(extract-analysis-cache "out/cljs/compiler.cljc.cache.edn" "out/cljs/compiler.cljc.cache.json")
(extract-analysis-cache "out/cljs/env.cljc.cache.edn" "out/cljs/env.cljc.cache.json")
(extract-analysis-cache "out/cljs/js.cljs.cache.edn" "out/cljs/js.cljs.cache.json")
(extract-analysis-cache "out/cljs/pprint.cljs.cache.edn" "out/cljs/pprint.cljs.cache.json")
(extract-analysis-cache "out/cljs/reader.cljs.cache.edn" "out/cljs/reader.cljs.cache.json")
(extract-analysis-cache "out/cljs/repl.cljs.cache.edn" "out/cljs/repl.cljs.cache.json")
(extract-analysis-cache "out/cljs/source_map.cljs.cache.edn" "out/cljs/source_map.cljs.cache.json")
(extract-analysis-cache "out/cljs/source_map/base64.cljs.cache.edn" "out/cljs/source_map/base64.cljs.cache.json")
(extract-analysis-cache "out/cljs/source_map/base64_vlq.cljs.cache.edn" "out/cljs/source_map/base64_vlq.cljs.cache.json")
(extract-analysis-cache "out/cljs/stacktrace.cljc.cache.edn" "out/cljs/stacktrace.cljc.cache.json")
(extract-analysis-cache "out/cljs/spec.cljs.cache.edn" "out/cljs/spec.cljs.cache.json")
(extract-analysis-cache "out/cljs/spec/impl/gen.cljs.cache.edn" "out/cljs/spec/impl/gen.cljs.cache.json")
(extract-analysis-cache "out/cljs/test.cljs.cache.edn" "out/cljs/test.cljs.cache.json")
(extract-analysis-cache "out/cljs/tagged_literals.cljc.cache.edn" "out/cljs/tagged_literals.cljc.cache.json")
(extract-analysis-cache "out/cljs/tools/reader.cljs.cache.edn" "out/cljs/tools/reader.cljs.cache.json")
(extract-analysis-cache "out/cljs/tools/reader/reader_types.cljs.cache.edn" "out/cljs/tools/reader/reader_types.cljs.cache.json")
(extract-analysis-cache "out/cljs/tools/reader/impl/commons.cljs.cache.edn" "out/cljs/tools/reader/impl/commons.cljs.cache.json")
(extract-analysis-cache "out/cljs/tools/reader/impl/utils.cljs.cache.edn" "out/cljs/tools/reader/impl/utils.cljs.cache.json")

(extract-analysis-cache "out/cognitect/transit.cljs.cache.edn" "out/cognitect/transit.cljs.cache.json")

(extract-analysis-cache "out/replete/repl.cljs.cache.edn" "out/replete/repl.cljs.cache.json")
(extract-analysis-cache "out/replete/repl_resources.cljs.cache.edn" "out/replete/repl_resources.cljs.cache.json")
(extract-analysis-cache "out/replete/core.cljs.cache.edn" "out/replete/core.cljs.cache.json")

(extract-analysis-cache "out/tailrecursion/cljson.cljs.cache.edn" "out/tailrecursion/cljson.cljs.cache.json")

(extract-analysis-cache "out/replete/pprint.cljs.cache.edn" "out/replete/pprint.cljs.cache.json")
(extract-analysis-cache "out/fipp/deque.cljc.cache.edn" "out/fipp/deque.cljc.cache.json")
(extract-analysis-cache "out/fipp/engine.cljc.cache.edn" "out/fipp/engine.cljc.cache.json")
(extract-analysis-cache "out/fipp/visit.cljc.cache.edn" "out/fipp/visit.cljc.cache.json")

(System/exit 0)
