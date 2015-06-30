# Replete

ClojureScript REPL iOS app.

Available for [beta testing](https://github.com/mfikes/replete/wiki/Beta).

Read more in blog post: [Replete: A Standalone iOS CLJS REPL](http://blog.fikesfarm.com/posts/2015-06-27-replete-a-standalone-ios-cljs-repl.html).

# Running

1. Build ClojureScript master (`script/build`).
2. Checkout David Nolen's [fork of `tools.reader`](https://github.com/swannodette/tools.reader) and do `lein install`.
3. Set the `project.clj` file so that it matches the ClojureScript master build number.
4. In the `ClojureScript/replete` directory, do `lein run -m clojure.main script/build.clj`
5. Do a `pod install` in the top level.
6. `open Replete.xcworkspace` and run the app on a device or in the simulator.
