(ns replete.test
  (:require [cljs.test :refer-macros [run-tests]]
            [replete.core-test]))

(enable-console-print!)

(defn ^:export run
  []
  (run-tests 'replete.core-test))

