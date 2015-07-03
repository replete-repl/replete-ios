(ns replete.core
  (:require-macros [cljs.env.macros :refer [ensure with-compiler-env]]
                   [cljs.analyzer.macros :refer [no-warn]])
  (:require [cljs.pprint :refer [pprint]]
            [cljs.tagged-literals :as tags]
            [cljs.tools.reader :as r]
            [cljs.tools.reader.reader-types :refer [string-push-back-reader]]
            [cljs.analyzer :as ana]
            [cljs.compiler :as c]
            [cljs.env :as env]
            [cljs.reader :as edn]
            [cognitect.transit :as t]
            [clojure.string :as s]))

(def DEBUG false)

(def cenv (env/default-compiler-env))

(defn ^:export load-core-cache [core-transit]
  (let [r (t/reader :json)
        core-cache (t/read r core-transit)]
    (swap! cenv assoc-in [::ana/namespaces 'cljs.core]
      core-cache)
    nil))

(defn ^:export load-macros-cache [macros-transit]
  (let [r (t/reader :json)
        macros-cache (t/read r macros-transit)]
    (swap! cenv assoc-in [::ana/namespaces 'cljs.core$macros]
      macros-cache)
    nil))

(defn ^:export is-readable? [line]
  (binding [r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (try
        (r/read-string line)
        true
        (catch :default _
          false)))))

(defn ^:export read-eval-print [line]
  (ns cljs.user)
  (binding [ana/*cljs-ns* 'cljs.user
            *ns* (create-ns 'cljs.user)
            r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (let [env (assoc (ana/empty-env) :context :expr
                                       :ns {:name 'cljs.user}
                                       :def-emits-var true)]
        (try
          (let [_ (when DEBUG (prn "line:" line))
                form (r/read-string line)
                _ (when DEBUG (prn "form:" form))
                ast (ana/analyze env form)
                _ (when DEBUG (prn "ast:" ast))
                js (with-out-str
                     (ensure
                       (c/emit ast)))
                _ (when DEBUG (prn "js:" js))]
            (try (prn (let [ret (js/eval js)]
                        (when-not ('#{*1 *2 *3 *e} form)
                          (set! *3 *2)
                          (set! *2 *1)
                          (set! *1 ret))
                        ret))
                 (catch js/Error e
                   (set! *e e)
                   (print (.-message e) "\n" (first (s/split (.-stack e) #"eval code"))))))
          (catch js/Error e
            (println (.-message e))))))))
