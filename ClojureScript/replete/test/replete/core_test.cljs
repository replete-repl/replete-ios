(ns replete.core-test
  (:require-macros [cljs.test :refer [use-fixtures deftest is]])
  (:require [cljs.test]
            [replete.core :refer [setup-cljs-user
                                  read-eval-print]]))

(deftest test-literal
  (is (= (with-out-str
           (read-eval-print "11"))
         "11\n")))

(deftest test-literal-keyword
  (is (= (with-out-str
           (read-eval-print ":yes"))
         ":yes\n")))

(deftest test-simple
  (is (= (with-out-str
           (read-eval-print "(+ 3 4)"))
         "7\n")))

(deftest test-complex
  (is (= (with-out-str
           (read-eval-print "(reduce + (map inc [1 2 3]))"))
         "9\n")))

