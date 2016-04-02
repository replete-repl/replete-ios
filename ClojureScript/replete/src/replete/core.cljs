(ns replete.core
  (:require-macros [cljs.env.macros :refer [ensure with-compiler-env]]
                   [cljs.analyzer.macros :refer [no-warn]])
  (:require [cljs.js :as cljs]
            [cljs.pprint :refer [pprint]]
            [cljs.tagged-literals :as tags]
            [cljs.tools.reader :as r]
            [cljs.tools.reader.reader-types :as rt :refer [string-push-back-reader]]
            [cljs.analyzer :as ana]
            [cljs.compiler :as c]
            [cljs.env :as env]
            [cljs.repl :as repl]
            [clojure.string :as s]
            [cljs.stacktrace :as st]
            [cljs.source-map :as sm]
            [tailrecursion.cljson :refer [cljson->clj]]
            [cljsjs.parinfer]
            [replete.repl-resources :refer [special-doc-map repl-special-doc-map]]))

(def DEBUG false)

(defonce st (cljs/empty-state))

(defn- known-namespaces
  []
  (keys (:cljs.analyzer/namespaces @st)))

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

(defn calc-x-line [text pos line]
  (let [x (s/index-of text "\n")]
    (if (or (nil? x)
            (< pos (inc x)))
      {:cursorX    pos
       :cursorLine line}
      (recur (subs text (inc x)) (- pos (inc x)) (inc line)))))

(defn first-non-space-pos-after [text pos]
  (if (= " " (subs text pos (inc pos)))
    (recur text (inc pos))
    pos))

(defn ^:export format [text pos enter-pressed?]
  (let [formatted-text (:text (js->clj
                                ((if enter-pressed?
                                   js/parinfer.parenMode
                                   js/parinfer.indentMode)
                                  text (clj->js (calc-x-line text pos 0)))
                                :keywordize-keys true))
        formatted-pos  (if enter-pressed?
                         (first-non-space-pos-after formatted-text pos)
                         pos)]
    #js [formatted-text formatted-pos]))

(def current-ns (atom 'cljs.user))

(defn- current-alias-map
  []
  (get-in @st [::ana/namespaces @current-ns :requires]))

(defn- all-ns
  "Returns a sequence of all namespaces."
  []
  (keys (::ana/namespaces @st)))

(defn- get-namespace
  "Gets the AST for a given namespace."
  [ns]
  {:pre [(symbol? ns)]}
  (get-in @st [::ana/namespaces ns]))

(defn- public-syms
  "Returns a sequence of the public symbols in a namespace."
  [ns]
  {:pre [(symbol? ns)]}
  (->> (get-namespace ns)
    :defs
    (filter (comp not :private second))
    (map key)))

(defn- get-aenv
  []
  (assoc (ana/empty-env)
    :ns (get-namespace @current-ns)
    :context :expr))

(defn ns-form? [form]
  (and (seq? form) (= 'ns (first form))))

(defn- repl-special?
  [form]
  (and (seq? form) (repl-special-doc-map (first form))))

(defn- special-doc
  [name-symbol]
  (assoc (special-doc-map name-symbol)
    :name name-symbol
    :special-form true))

(defn- repl-special-doc
  [name-symbol]
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

(defn- pre-compiled-callaback-data [path]
  (prn path)
  (when-let [js-source (js/REPLETE_LOAD (str path ".js"))]
    (when-let [cache (js/REPLETE_LOAD (str path ".cljs.cache.edn"))]
      {:lang   :js
       :source js-source
       :cache  (r/read-string cache)})))

(defn- source-callback-data [path extension]
  (when-let [source (js/REPLETE_LOAD (str path extension))]
    {:lang   (extension->lang extension)
     :source source}))

(defn load-and-callback! [path extension cb]
  (when-let [cb-data (or (and (= ".cljs" extension)
                              (pre-compiled-callaback-data path))
                         (source-callback-data path extension))]
    (cb cb-data)
    :loaded))

(defn- closure-index
  []
  (let [paths-to-provides
        (map (fn [[_ path provides]]
               [path (map second
                       (re-seq #"'(.*?)'" provides))])
          (re-seq #"\ngoog\.addDependency\('(.*)', \[(.*?)\].*"
            (js/REPLETE_LOAD "goog/deps.js")))]
    (into {}
      (for [[path provides] paths-to-provides
            provide provides]
        [(symbol provide) (str "goog/" (second (re-find #"(.*)\.js$" path)))]))))

(def ^:private closure-index-mem (memoize closure-index))

(defn- skip-load?
  [{:keys [name macros]}]
  (or
    (= name 'cljsjs.parinfer)
    (= name 'cljs.core)
    (and (= name 'cljs.env.macros) macros)
    (and (= name 'cljs.analyzer.macros) macros)
    (and (= name 'cljs.compiler.macros) macros)
    (and (= name 'cljs.repl) macros)
    (and (= name 'cljs.js) macros)
    (and (= name 'cljs.pprint) macros)
    (and (= name 'clojure.template) macros)
    (and (= name 'tailrecursion.cljson) macros)))

;; Represents code for which the goog JS is already loaded
(defn- skip-load-goog-js?
  [name]
  ('#{goog.object
      goog.string
      goog.string.StringBuffer
      goog.math.Long} name))

(defn- do-load-goog
  [name cb]
  (if (skip-load-goog-js? name)
    (cb {:lang   :js
         :source ""})
    (if-let [goog-path (get (closure-index-mem) name)]
      (when-not (load-and-callback! goog-path ".js" cb)
        (cb nil))
      (cb nil))))

(defn load [{:keys [name macros path] :as full} cb]
  (cond
    (skip-load? full) (cb {:lang   :js
                           :source ""})
    (re-matches #"^goog/.*" path) (do-load-goog name cb)
    :else (loop [extensions (if macros
                              [".clj" ".cljc"]
                              [".cljs" ".cljc" ".js"])]
            (if extensions
              (when-not (load-and-callback! path (first extensions) cb)
                (recur (next extensions)))
              (cb nil)))))

(defn- canonicalize-specs
  [specs]
  (letfn [(canonicalize [quoted-spec-or-kw]
            (if (keyword? quoted-spec-or-kw)
              quoted-spec-or-kw
              (as-> (second quoted-spec-or-kw) spec
                (if (vector? spec) spec [spec]))))]
    (map canonicalize specs)))

(defn- purge-analysis-cache!
  [state ns]
  (swap! state (fn [m]
                 (assoc m ::ana/namespaces (dissoc (::ana/namespaces m) ns)))))

(defn- purge!
  [names]
  (doseq [name names]
    (purge-analysis-cache! st name))
  (apply swap! cljs.js/*loaded* disj names))

(defn- process-reloads!
  [specs]
  (if-let [k (some #{:reload :reload-all} specs)]
    (let [specs (->> specs (remove #{k}))]
      (if (= k :reload-all)
        (purge! @cljs.js/*loaded*)
        (purge! (map first specs)))
      specs)
    specs))

(defn- self-require?
  [specs]
  (some
    (fn [quoted-spec-or-kw]
      (and (not (keyword? quoted-spec-or-kw))
           (let [spec (second quoted-spec-or-kw)
                 ns   (if (sequential? spec)
                        (first spec)
                        spec)]
             (= ns @current-ns))))
    specs))

(defn- make-ns-form
  [kind specs target-ns]
  (if (= kind :import)
    (with-meta `(~'ns ~target-ns
                  (~kind
                    ~@(map (fn [quoted-spec-or-kw]
                             (if (keyword? quoted-spec-or-kw)
                               quoted-spec-or-kw
                               (second quoted-spec-or-kw)))
                        specs)))
      {:merge true :line 1 :column 1})
    (with-meta `(~'ns ~target-ns
                  (~kind
                    ~@(-> specs canonicalize-specs process-reloads!)))
      {:merge true :line 1 :column 1})))

(declare make-base-eval-opts)
(declare print-error)

(defn- process-require
  [kind cb specs]
  (let [current-st @st]
    (try
      (let [is-self-require? (and (= :kind :require) (self-require? specs))
            [target-ns restore-ns]
            (if-not is-self-require?
              [@current-ns nil]
              ['cljs.user @current-ns])]
        (cljs/eval
          st
          (make-ns-form kind specs target-ns)
          (merge (make-base-eval-opts)
            {:load load})
          (fn [{e :error}]
            (when is-self-require?
              (reset! current-ns restore-ns))
            (when e
              (print-error e)
              (reset! st current-st))
            (cb))))
      (catch :default e
        (print-error e)
        (reset! st current-st)))))

(defn- resolve-var
  "Given an analysis environment resolve a var. Analogous to
   clojure.core/resolve"
  [env sym]
  {:pre [(map? env) (symbol? sym)]}
  (try
    (ana/resolve-var env sym
      (ana/confirm-var-exists-throw))
    (catch :default _
      (ana/resolve-macro-var env sym))))

(defn load-core-source-maps! []
  (when-not (get (:source-maps @st) 'cljs.core)
    (swap! st update-in [:source-maps] merge {'cljs.core
                                              (sm/decode
                                                (cljson->clj
                                                  (js/REPLETE_LOAD "cljs/core.js.map")))})))

(defn unmunge-core-fn [munged-name]
  (s/replace munged-name #"^cljs\$core\$" "cljs.core/"))

(defn mapped-stacktrace-str
  "Given a vector representing the canonicalized JavaScript stacktrace and a map
  of library names to decoded source maps, print the ClojureScript stacktrace .
  See mapped-stacktrace."
  ([stacktrace sms]
   (mapped-stacktrace-str stacktrace sms nil))
  ([stacktrace sms opts]
   (with-out-str
     (doseq [{:keys [function file line column]}
             (st/mapped-stacktrace stacktrace sms opts)]
       (println
         (str (when function (str (unmunge-core-fn function) " "))
           "(" file (when line (str ":" line))
           (when column (str ":" column)) ")"))))))

(defn print-error
  ([error]
   (print-error error false))
  ([error include-stacktrace?]
   (let [e (or (.-cause error) error)]
     (println (.-message e)
       (when include-stacktrace?
         (str "\n" (.-stack e)))))))

(defn- get-macro-var
  [env sym macros-ns]
  {:pre [(symbol? macros-ns)]}
  (let [macros-ns-str (str macros-ns)
        base-ns-str   (subs macros-ns-str 0 (- (count macros-ns-str) 7))
        base-ns       (symbol base-ns-str)]
    (if-let [macro-var (with-compiler-env st
                         (resolve-var env (symbol macros-ns-str (name sym))))]
      (update (assoc macro-var :ns base-ns)
        :name #(symbol base-ns-str (name %))))))

(defn- all-macros-ns
  []
  (->> (all-ns)
    (filter #(s/ends-with? (str %) "$macros"))))

(defn- get-var
  [env sym]
  (let [var (or (with-compiler-env st (resolve-var env sym))
                (some #(get-macro-var env sym %) (all-macros-ns)))]
    (when var
      (if (= (namespace (:name var)) (str (:ns var)))
        (update var :name #(symbol (name %)))
        var))))

(defn- get-file-source
  [filepath]
  (if (symbol? filepath)
    (let [without-extension (s/replace
                              (s/replace (name filepath) #"\." "/")
                              #"-" "_")]
      (or
        (js/REPLETE_LOAD (str without-extension ".clj"))
        (js/REPLETE_LOAD (str without-extension ".cljc"))
        (js/REPLETE_LOAD (str without-extension ".cljs"))))
    (let [file-source (js/REPLETE_LOAD filepath)]
      (or file-source
          (js/REPLETE_LOAD (s/replace filepath #"^out/" ""))
          (js/REPLETE_LOAD (s/replace filepath #"^src/" ""))
        (js/REPLETE_LOAD (s/replace filepath #"^/.*/planck-cljs/src/" ""))))))

(defn- fetch-source
  [var]
  (when-let [filepath (or (:file var) (:file (:meta var)))]
    (when-let [file-source (get-file-source filepath)]
      (let [rdr (rt/source-logging-push-back-reader file-source)]
        (dotimes [_ (dec (:line var))] (rt/read-line rdr))
        (-> (r/read {:read-cond :allow :features #{:cljs}} rdr)
          meta :source)))))

(defn- make-base-eval-opts
  []
  {:ns      @current-ns
   :context :expr
   :eval    cljs/js-eval})

(defn- process-in-ns
  [argument]
  (cljs/eval
    st
    argument
    (make-base-eval-opts)
    (fn [result]
      (if (and (map? result) (:error result))
        (print-error (:error result))
        (let [ns-name result]
          (if-not (symbol? ns-name)
            (println "Argument to in-ns must be a symbol.")
            (if (some (partial = ns-name) (known-namespaces))
              (reset! current-ns ns-name)
              (let [ns-form `(~'ns ~ns-name)]
                (cljs/eval
                  st
                  ns-form
                  (make-base-eval-opts)
                  (fn [{e :error}]
                    (if e
                      (print-error e)
                      (reset! current-ns ns-name))))))))))))

(defn- dir*
  [nsname]
  (run! prn
    (distinct (sort (concat
                      (public-syms nsname)
                      (public-syms (symbol (str (name nsname) "$macros"))))))))

(defn- apropos*
  [str-or-pattern]
  (let [matches? (if (instance? js/RegExp str-or-pattern)
                   #(re-find str-or-pattern (str %))
                   #(s/includes? (str %) (str str-or-pattern)))]
    (sort (mapcat (fn [ns]
                    (let [ns-name (str ns)
                          ns-name (if (s/ends-with? ns-name "$macros")
                                    (apply str (drop-last 7 ns-name))
                                    ns-name)]
                      (map #(symbol ns-name (str %))
                        (filter matches? (public-syms ns)))))
            (all-ns)))))

(defn- doc*
  [sym]
  (if-let [special-sym ('{&       fn
                          catch   try
                          finally try} sym)]
    (doc* special-sym)
    (cond

      (special-doc-map sym)
      (repl/print-doc (special-doc sym))

      (repl-special-doc-map sym)
      (repl/print-doc (repl-special-doc sym))

      (get-namespace sym)
      (cljs.repl/print-doc
        (select-keys (get-namespace sym) [:name :doc]))

      (get-var (get-aenv) sym)
      (repl/print-doc
        (let [var (get-var (get-aenv) sym)
              var (update var
                    :doc (if (user-interface-idiom-ipad?)
                           identity
                           reflow))
              var (assoc var :forms (-> var :meta :forms second)
                             :arglists (-> var :meta :arglists second))
              m   (select-keys var
                    [:ns :name :doc :forms :arglists :macro :url])]
          (cond-> (update-in m [:name] name)
            (:protocol-symbol var)
            (assoc :protocol true
                   :methods
                   (->> (get-in var [:protocol-info :methods])
                     (map (fn [[fname sigs]]
                            [fname {:doc      (:doc
                                                (get-var (get-aenv)
                                                  (symbol (str (:ns var)) (str fname))))
                                    :arglists (seq sigs)}]))
                     (into {})))))))))

(defn- find-doc*
  [re-string-or-pattern]
  (let [re       (re-pattern re-string-or-pattern)
        sym-docs (sort-by first
                   (mapcat (fn [ns]
                             (map (juxt first (comp :doc second))
                               (get-in @st [::ana/namespaces ns :defs])))
                     (all-ns)))]
    (doseq [[sym doc] sym-docs
            :when (and doc
                       (name sym)
                       (or (re-find re doc)
                           (re-find re (name sym))))]
      (doc* sym))))

(defn- source*
  [sym]
  (println (or (fetch-source (get-var (get-aenv) sym))
               "Source not found")))

(defn- pst*
  ([]
   (pst* '*e))
  ([expr]
   (try (cljs/eval st
          expr
          (make-base-eval-opts)
          (fn [{:keys [value]}]
            (when value
              (print-error value true))))
        (catch js/Error e (prn :caught e)))))

(defn ^:export read-eval-print
  ([source]
   (read-eval-print source true))
  ([source expression?]
   (binding [ana/*cljs-ns* @current-ns
             env/*compiler* st
             *ns* (create-ns @current-ns)
             r/*data-readers* tags/*cljs-data-readers*
             r/resolve-symbol ana/resolve-symbol
             r/*alias-map* (current-alias-map)]
     (try
       (let [expression-form (and expression? (repl-read-string source))]
         (if (repl-special? expression-form)
           (let [argument (second expression-form)]
             (case (first expression-form)
               in-ns (process-in-ns argument)
               require (process-require :require identity (rest expression-form))
               require-macros (process-require :require-macros identity (rest expression-form))
               import (process-require :import identity (rest expression-form))
               dir (dir* argument)
               apropos (apropos* argument)
               doc (doc* argument)
               find-doc (find-doc* argument)
               source (source* argument)
               pst (if argument
                     (pst* argument)
                     (pst*)))
             (prn nil))
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
                 (print-error error))))))
       (catch :default e
         (print-error e))))))
