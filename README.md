# Replete

ClojureScript REPL iOS app.

This app presents a self-contained (no network connectivity needed) ClojureScript REPL, based on the recent bootstrapped ClojureScript compiler work. My intent is to polish this app and release it as a free app in the App Store.

# Running

1. In the `ClojureScript\replete` directory, do `lein run -m clojure.main script/build.clj`
2. Do a `pod install` in the top level.
3. Open the xcworkspace file and run the app on a device or in the simulator.
