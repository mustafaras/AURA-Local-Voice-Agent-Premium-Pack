import Foundation

// App extensions are started by `NSExtensionMain`, which reads the bundle's
// `NSExtension` dictionary and vends the principal class over XPC. Xcode
// supplies it by overriding the link-time entry point; SwiftPM has no such
// setting, so the executable's own `main` calls it directly. The effect is
// identical — this process never runs any other code path — and it keeps the
// appex buildable by the same `swift build` the rest of the package uses.
@_silgen_name("NSExtensionMain")
func auraNSExtensionMain() -> Int32

// Referencing the principal class here keeps the linker from dropping it: it
// is only ever instantiated by name from the Objective-C runtime.
_ = SafariWebExtensionHandler.self

exit(auraNSExtensionMain())
