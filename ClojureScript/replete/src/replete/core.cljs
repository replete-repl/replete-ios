(ns replete.core
  (:require-macros [cljs.env.macros :refer [ensure with-compiler-env]]
                   [cljs.analyzer.macros :refer [no-warn]])
  (:require [cljs.pprint :refer [pprint]]
            [cljs.reader :as r]
            [cljs.analyzer :as ana]
            [cljs.compiler :as c]
            [cljs.env :as env]
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

(defn ^:export setup-cljs-user []
  (js/eval "goog.provide('cljs.user')")
  (js/eval "goog.require('cljs.core')"))

(defn ^:export is-readable? [line]
  (with-compiler-env cenv
    (try
      (r/read-string line)
      true
      (catch :default _
        false))))

(def current-ns (atom 'cljs.user))

(defn ns-form? [form]
  (and (seq? form) (= 'ns (first form))))

(defn repl-special? [form]
  (and (seq? form) (= 'in-ns (first form))))

(defn ^:export read-eval-print [line]
  (binding [ana/*cljs-ns* @current-ns
            *ns* (create-ns @current-ns)]
    (with-compiler-env cenv
      (let [env (assoc (ana/empty-env) :context :expr
                                       :ns {:name @current-ns}
                                       :def-emits-var true)]
        (try
          (let [_ (when DEBUG (prn "line:" line))
                form (r/read-string line)]
            (if (repl-special? form)
              (case (first form)
                'in-ns (reset! current-ns (second (second form))))
              (let [_ (when DEBUG (prn "form:" form))
                    ast (ana/analyze env form)
                    _ (when DEBUG (prn "ast:" ast))
                    js (with-out-str
                         (ensure
                           (c/emit ast)))
                    _ (when DEBUG (prn "js:" js))]
                (try (prn (let [ret (js/eval js)]
                            (when-not
                              (or ('#{*1 *2 *3 *e} form)
                                (ns-form? form))
                              (set! *3 *2)
                              (set! *2 *1)
                              (set! *1 ret))
                            (reset! current-ns ana/*cljs-ns*)
                            ret))
                     (catch js/Error e
                       (set! *e e)
                       (print (.-message e) "\n" (first (s/split (.-stack e) #"eval code"))))))))
          (catch js/Error e
            (println (.-message e))))))))
