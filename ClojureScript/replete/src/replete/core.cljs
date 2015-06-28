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
            [cljs.reader :as edn]))

(def DEBUG false)

(def cenv (env/default-compiler-env))

(defn ^:export load-core-cache [core-edn]
  (swap! cenv assoc-in [::ana/namespaces 'cljs.core]
    (edn/read-string core-edn)))

(defn ^:export load-macros-cache [macros-edn]
  (swap! cenv assoc-in [::ana/namespaces 'cljs.core$macros]
    (edn/read-string macros-edn)))

(defn read-eval-print [line]
  (binding [ana/*cljs-ns* 'replete.core
            *ns* (create-ns 'replete.core)
            r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (let [env (assoc (ana/empty-env) :context :expr
                                       :ns {:name 'replete.core}
                                       :def-emits-var true)]
        (try
          (let [_ (when DEBUG (prn "line:" line))
                form (r/read-string line)
                _ (when DEBUG (prn "form:" form))
                ast (no-warn (ana/analyze env form))
                _ (when DEBUG (prn "ast:" ast))
                js (with-out-str
                     (ensure
                       (c/emit ast)))
                _ (when DEBUG (prn "js:" js))]
            (println (js/eval js)))
          (catch js/Error e
            (println (str (.-message e) "\n" (.-stack e)))))))))
