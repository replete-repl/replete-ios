# Replete

ClojureScript REPL iOS app.

Available [on the App Store](https://itunes.apple.com/us/app/replete/id1013465639?ls=1&mt=8).

[Announcement post](http://blog.fikesfarm.com/posts/2015-07-20-ios-clojurescript-repl-available-in-app-store.html)

Earlier post: [Replete: A Standalone iOS CLJS REPL](http://blog.fikesfarm.com/posts/2015-06-27-replete-a-standalone-ios-cljs-repl.html).

Interested in Android instead? See [Replicator](https://github.com/tahmidsadik112/Replicator).

# Running

1. Clone and build ClojureScript master (`script/build`).
2. Clone David Nolen's [fork of `tools.reader`](https://github.com/swannodette/tools.reader), switch to the `cljs-bootstrap` branch and do `lein install`.
3. Set the `project.clj` file so that it matches the ClojureScript master build number.
4. In the `ClojureScript/replete` directory, do `lein run -m clojure.main script/build.clj`
5. Do a `pod install` in the top level.
6. `open Replete.xcworkspace` and run the app on a device or in the simulator.

# Contributing

Happy to take PRs!

# License

Copyright © 2015 Mike Fikes and Contributors

Distributed under the Eclipse Public License either version 1.0 or (at your option) any later version.
