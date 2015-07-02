(ns script.bootstrap.build
  (:require [clojure.java.io :as io]
            [cljs.closure :as closure]
            [cljs.env :as env]
            [clojure.edn :as edn]
            [cognitect.transit :as transit])
  (:import [java.io FileOutputStream]))

(defn compile1 [copts file]
  (let [targ (io/resource file)
        _ (println "Compiling:" targ)
        core-js (closure/compile targ
                  (assoc copts
                    :output-file (closure/src-file->target-file targ)))
        deps    (closure/add-dependencies copts core-js)]
    deps))

(defn build [dir file opts]
  ;; Used to generate core$macros
  (io/make-parents "resources/cljs/core.cljc")
  ;; TODO: only do this if timestamps are newer
  ;;(if (not (.exists (io/as-file "resources/cljs/core.cljc"))))
  (spit "resources/cljs/core.cljc" (slurp (io/resource "cljs/core.cljc")))
  (spit "resources/cljs/core.cljs" (slurp (io/resource "cljs/core.cljs")))
  ;; Compilation core.cljc below breaks if the cache file is present
  (io/delete-file "resources/cljs/core.cljs.cache.aot.edn" true)

  (let [output-dir (io/file dir)
        copts (assoc opts
                :output-dir output-dir
                :cache-analysis true
                :source-map true
                :def-emits-var true)]
    (env/with-compiler-env (env/default-compiler-env opts)
      (let [;; Generate core$macros
            deps-macros (compile1 copts "cljs/core.cljc")
            ;; Compile main file
            deps (compile1 copts file)]
        ;; output unoptimized code and the deps file
        ;; for all compiled namespaces
        (apply closure/output-unoptimized
          (assoc copts
            :output-to (.getPath (io/file output-dir "deps.js")))
          (concat deps deps-macros)))))

  ;; TODO: this should really come from the compilation above
  (let [core-cache (edn/read-string (slurp (io/resource "cljs/core.cljs.cache.aot.edn")))
        out (FileOutputStream. "./resources/cljs/core.cljs.cache.aot.transit")
        writer (transit/writer out :json)
        _ (transit/write writer core-cache)]
    (.close out))

  (let [core-macros-cache (edn/read-string (slurp "out/cljs/core$macros.cljc.cache.edn"))
        out (FileOutputStream. "./resources/cljs/core$macros.cljc.cache.transit")
        writer (transit/writer out :json)
        _ (transit/write writer core-macros-cache)]
    (.close out)))

(println "Building")
(build "out" "replete/core.cljs" nil)
(println "Done building")
