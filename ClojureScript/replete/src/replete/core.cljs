(ns replete.core
  (:require-macros [cljs.env.macros :refer [ensure with-compiler-env]]
                   [cljs.analyzer.macros :refer [no-warn]])
  (:require [cljs.js :as cljs]
            [cljs.pprint :refer [pprint]]
            [cljs.tagged-literals :as tags]
            [cljs.tools.reader :as r]
            [cljs.tools.reader.reader-types :refer [string-push-back-reader]]
            [cljs.analyzer :as ana]
            [cljs.compiler :as c]
            [cljs.env :as env]
            [cljs.repl :as repl]
            [clojure.string :as s]))

(def DEBUG false)

(defonce st (cljs/empty-state))

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
    (with-compiler-env st
      (try
        (repl-read-string line)
        true
        (catch :default _
          false)))))

(def current-ns (atom 'cljs.user))

(defn ns-form? [form]
  (and (seq? form) (= 'ns (first form))))

(def repl-specials '#{in-ns require require-macros doc})

(defn repl-special? [form]
  (and (seq? form) (repl-specials (first form))))

(def repl-special-doc-map
  '{in-ns          {:arglists ([name])
                    :doc      "Sets *cljs-ns* to the namespace named by the symbol, creating it if needed."}
    require        {:arglists ([& args])
                    :doc      "Loads libs, skipping any that are already loaded."}
    require-macros {:arglists ([& args])
                    :doc      "Similar to the require REPL special function but
                    only for macros."}
    doc            {:arglists ([name])
                    :doc      "Prints documentation for a var or special form given its name"}})

(defn- repl-special-doc [name-symbol]
  (assoc (repl-special-doc-map name-symbol)
    :name name-symbol
    :repl-special-function true))

(defn reflow [text]
  (and text
    (-> text
     (s/replace #" \n  " "")
     (s/replace #"\n  " " "))))

;; Copied from cljs.analyzer.api (which hasn't yet been converted to cljc)
(defn resolve
  "Given an analysis environment resolve a var. Analogous to
   clojure.core/resolve"
  [env sym]
  {:pre [(map? env) (symbol? sym)]}
  (try
    (ana/resolve-var env sym
      (ana/confirm-var-exists-throw))
    (catch :default _
      (ana/resolve-macro-var env sym))))

(defn extension->lang [extension]
  (if (= ".js" extension)
    :js
    :clj))

(defn load-and-callback! [path extension cb]
  (when-let [source (js/REPLETE_LOAD (str path extension))]
    (cb {:lang   (extension->lang extension)
         :source source})
    :loaded))

(defn load [{:keys [name macros path] :as full} cb]
  #_(prn full)
  (loop [extensions (if macros
                      [".clj" ".cljc"]
                      [".cljs" ".cljc" ".js"])]
    (if extensions
      (when-not (load-and-callback! path (first extensions) cb)
        (recur (next extensions)))
      (cb nil))))

(defn require [macros-ns? sym reload]
  (cljs.js/require
    {:*compiler*     st
     :*data-readers* tags/*cljs-data-readers*
     :*load-fn*      load
     :*eval-fn*      cljs/js-eval}
    sym
    reload
    {:macros-ns macros-ns?
     :verbose   (:verbose @app-env)}
    (fn [res]
      #_(println "require result:" res))))

(defn require-destructure [macros-ns? args]
  (let [[[_ sym] reload] args]
    (require macros-ns? sym reload)))

(defn print-error [error]
  (let [cause (.-cause error)]
    (println (.-message cause))
    (println (.-stack cause))))

(defn ^:export read-eval-print
  ([source]
   (read-eval-print source true))
  ([source expression?]
   (binding [ana/*cljs-ns* @current-ns
             *ns* (create-ns @current-ns)
             r/*data-readers* tags/*cljs-data-readers*]
     (let [expression-form (and expression? (repl-read-string source))]
       (if (repl-special? expression-form)
         (let [env (assoc (ana/empty-env) :context :expr
                                          :ns {:name @current-ns})]
           (case (first expression-form)
             in-ns (reset! current-ns (second (second expression-form)))
             require (require-destructure false (rest expression-form))
             require-macros (require-destructure true (rest expression-form))
             doc (if (repl-specials (second expression-form))
                   (repl/print-doc (repl-special-doc (second expression-form)))
                   (repl/print-doc
                     (let [sym (second expression-form)
                           var (with-compiler-env st
                                 (resolve env sym))]
                       (update (:meta var)
                         :doc (if (user-interface-idiom-ipad?)
                                identity
                                reflow))))))
           (prn nil))
         (try
           (cljs/eval-str
             st
             source
             (if expression? source "File")
             (merge
               {:ns         @current-ns
                :load       load
                :eval       cljs/js-eval
                :source-map false
                :verbose    (:verbose @app-env)}
               (when expression?
                 {:context       :expr
                  :def-emits-var true}))
             (fn [{:keys [ns value error] :as ret}]
               (if expression?
                 (if-not error
                   (do
                     (prn value)
                     (when-not
                       (or ('#{*1 *2 *3 *e} expression-form)
                         (ns-form? expression-form))
                       (set! *3 *2)
                       (set! *2 *1)
                       (set! *1 value))
                     (reset! current-ns ns)
                     nil)
                   (do
                     (set! *e error))))
               (when error
                 (print-error error))))
           (catch :default e
             (print-error e))))))))

#_(defn read-eval-print-form [form env]
  (let [_ (when DEBUG (prn "form:" form))]
    (if (repl-special? form)
      (case (first form)
        in-ns (reset! current-ns (second (second form)))
        doc (if (repl-specials (second form))
              (repl/print-doc (repl-special-doc (second form)))
              (repl/print-doc
               (let [sym (second form)
                     var (resolve env sym)]
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
               (print (.-message e) "\n" (first (s/split (.-stack e) #"eval code")))))))))

#_(defn ^:export read-eval-print-orig [lines]
  (binding [ana/*cljs-ns* @current-ns
            *ns* (create-ns @current-ns)
            r/*data-readers* tags/*cljs-data-readers*]
    (with-compiler-env cenv
      (let [env (assoc (ana/empty-env) :context :expr
                                       :ns {:name @current-ns}
                                       :def-emits-var true)]
        (try
          (let [infile (string-push-back-reader lines)
                eof (js-obj)]
            (loop []
              (let [form (r/read {:eof eof :read-cond :allow :features #{:cljs}} infile)]
                (when-not (identical? eof form)
                  (read-eval-print-form form env)
                  (recur)))))
          (catch js/Error e
            (println (.-message e))))))))
