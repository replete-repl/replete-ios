# Replete

ClojureScript REPL iOS app.

Interested in Android instead? See [Replete for Android](https://github.com/replete-repl/replete-android).

Available [on the App Store](https://itunes.apple.com/us/app/replete/id1013465639?ls=1&mt=8).

[Announcement post](http://blog.fikesfarm.com/posts/2015-07-20-ios-clojurescript-repl-available-in-app-store.html)

Earlier post: [Replete: A Standalone iOS CLJS REPL](http://blog.fikesfarm.com/posts/2015-06-27-replete-a-standalone-ios-cljs-repl.html).

# Build Curl for iOS

1. Clone `https://github.com/jasonacox/Build-OpenSSL-cURL`
1. Go into that project and run `./build.sh`
1. Copy the resulting `curl`, `openssl` and `nghttp2` directories into the `Replete` directory.
1. The Xcode project is already set up to look in these directories for headers and static libs.

# Running

1. Clone [planck](https://github.com/mfikes/planck) into a sibling directory and build it.
1. In the `ClojureScript/replete` directory, do `script/build`
1. Do a `pod install` in the top level.
1. `open Replete.xcworkspace` with Xcode and run the app on a device or in the simulator.

# Contributing

Happy to take PRs!

# License

Copyright © 2015–2019 Mike Fikes, Roman Liutikov, and Contributors

Distributed under the Eclipse Public License either version 1.0 or (at your option) any later version.
