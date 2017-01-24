(ns replete.repl)

(defmacro ^:private with-err-str
  "Evaluates exprs in a context in which *print-err-fn* is bound to .append
  on a fresh StringBuffer.  Returns the string created by any nested
  printing calls."
  [& body]
  `(let [sb# (js/goog.string.StringBuffer.)]
     (binding [cljs.core/*print-newline* true
               cljs.core/*print-err-fn* (fn [x#] (.append sb# x#))]
       ~@body)
     (str sb#)))