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
            [cljs.repl :as repl]
            [clojure.string :as s]))

(def DEBUG false)

(def cenv (env/default-compiler-env))

(defn load-cache [cache where]
  (swap! cenv assoc-in [::ana/namespaces where] cache)
  nil)

(defn ^:export load-core-js [code]
  (load-cache (js/eval code) 'cljs.core))

(defn ^:export load-macros-js [code]
  (load-cache (js/eval code) 'cljs.core$macros))

(defn ^:export setup-cljs-user []
  (js/eval "goog.provide('cljs.user')")
  (js/eval "goog.require('cljs.core')"))

(def app-env (atom nil))

(defn map-keys [f m]
  (reduce-kv (fn [r k v] (assoc r (f k) v)) {} m))

(defn ^:export init-app-env [app-env]
  (reset! replete.core/app-env (map-keys keyword (cljs.core/js->clj app-env))))

(defn user-interface-idiom-ipad?
  "Returns true iff the interface idiom is iPad."
  []
  (= "iPad" (:user-interface-idiom @app-env)))

(defn repl-read-string [line]
  (r/read-string {:read-cond :allow :features #{:cljs}} line))

(defn ^:export is-readable? [line]
  (binding [r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (try
        (repl-read-string line)
        true
        (catch :default _
          false)))))

(def current-ns (atom 'cljs.user))

(defn ns-form? [form]
  (and (seq? form) (= 'ns (first form))))

(def repl-specials '#{in-ns doc})

(defn repl-special? [form]
  (and (seq? form) (repl-specials (first form))))

(def repl-special-doc-map
  '{in-ns {:arglists ([name])
           :doc "Sets *cljs-ns* to the namespace named by the symbol, creating it if needed."}
    doc {:arglists ([name])
         :doc "Prints documentation for a var or special form given its name"}})

(defn- repl-special-doc [name-symbol]
  (assoc (repl-special-doc-map name-symbol)
    :name name-symbol
    :repl-special-function true))

(defn reflow [text]
  (and text
    (-> text
     (s/replace #" \n  " "")
     (s/replace #"\n  " " "))))

(defn ^:export read-eval-print [line]
  (binding [ana/*cljs-ns* @current-ns
            *ns* (create-ns @current-ns)
            r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (let [env (assoc (ana/empty-env) :context :expr
                                       :ns {:name @current-ns}
                                       :def-emits-var true)]
        (try
          (let [_ (when DEBUG (prn "line:" line))
                form (repl-read-string line)]
            (if (repl-special? form)
              (case (first form)
                in-ns (reset! current-ns (second (second form)))
                doc (if (repl-specials (second form))
                      (repl/print-doc (repl-special-doc (second form)))
                      (repl/print-doc
                        (let [sym (second form)
                              var (ana/resolve-var env sym)]
                          (update (:meta var)
                            :doc (if (user-interface-idiom-ipad?)
                                   identity
                                   reflow))))))
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
