# Replete

ClojureScript REPL iOS app.

Read more in blog post: [Replete: A Standalone iOS CLJS REPL](http://blog.fikesfarm.com/posts/2015-06-27-replete-a-standalone-ios-cljs-repl.html).

# Running

1. Build ClojureScript master and David Nolen's fork of `tools.reader`.
2. Set the `project.clj` file so that it matches the ClojureScript master build number.
1. In the `ClojureScript/replete` directory, do `lein run -m clojure.main script/build.clj`
2. Do a `pod install` in the top level.
3. `open Replete.xcworkspace` and run the app on a device or in the simulator.
