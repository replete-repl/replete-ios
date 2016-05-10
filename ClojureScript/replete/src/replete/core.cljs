(ns replete.core
  (:require [replete.repl :as repl]))

(defn eval
  "Evaluates the form data structure (not text!) and returns the result."
  [form]
  (repl/eval form))

(defn ns-resolve
  "Returns the var to which a symbol will be resolved in the namespace,
  else nil."
  [ns sym]
  (repl/ns-resolve ns sym))

(defn resolve
  "Returns the var to which a symbol will be resolved in the current
  namespace, else nil."
  [sym]
  (repl/resolve sym))

(defn intern
  "Finds or creates a var named by the symbol name in the namespace
  ns (which can be a symbol or a namespace), setting its root binding
  to val if supplied. The namespace must exist. The var will adopt any
  metadata from the name symbol.  Returns the var."
  ([ns name]
   (when-let [the-ns (find-ns (cond-> ns (instance? Namespace ns) ns-name))]
     (repl/eval `(def ~name) (ns-name the-ns))))
  ([ns name val]
   (when-let [the-ns (find-ns (cond-> ns (instance? Namespace ns) ns-name))]
     (repl/eval `(def ~name ~val) (ns-name the-ns)))))
