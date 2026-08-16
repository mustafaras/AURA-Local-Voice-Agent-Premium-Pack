import Foundation

/// The filesystem roots AURA's reversible open/reveal capabilities are
/// confined to, declared once so the policy layer and the adapter layer
/// cannot drift apart.
///
/// SP-006's closeout found that *neither* layer confined targets in
/// production. The seeded grants used `patterns: [.any]`, and every
/// production `FileSystemURLOpener` was built with `OpenTargetValidator`'s
/// default `approvedRoots: []`, which the validator documents as "no root
/// restriction". Refusal therefore rested entirely on the validator's
/// executable-extension and sensitive-fragment rules — real protections, but
/// nothing stopped an arbitrary readable path elsewhere on the volume from
/// being opened.
///
/// Both layers now read this list, so a target outside these roots is refused
/// twice and for independent reasons: once by a `.directory(_:recursive:)`
/// grant pattern *before* the adapter is reached, and again by
/// `PathConfinement` inside the adapter after canonicalization. That ordering
/// matters — the policy check is a prefix test on the caller's raw path, while
/// the adapter's check runs on the canonical path, so a `..` or symlink escape
/// that slips past the first is still caught by the second.
public enum DeclaredFileRoots {
  /// Canonical roots, de-duplicated, without trailing separators.
  ///
  /// `/tmp` and `/private/tmp` are both listed deliberately: `/tmp` is a
  /// symlink to `/private/tmp` on macOS, and the policy layer compares raw
  /// strings while the adapter compares canonicalized ones, so the same
  /// directory has two spellings depending on which layer is looking.
  public static let all: [String] = {
    let candidates = [
      NSHomeDirectory(),
      NSTemporaryDirectory(),
      "/tmp",
      "/private/tmp",
    ]
    var seen = Set<String>()
    var roots: [String] = []
    for candidate in candidates {
      let trimmed =
        candidate.hasSuffix("/") && candidate != "/"
        ? String(candidate.dropLast())
        : candidate
      guard !trimmed.isEmpty else { continue }
      // Record both the raw spelling and its canonical form. The adapter
      // canonicalizes roots and targets before comparing, so it does not care
      // — but the policy layer compares raw strings, and `NSTemporaryDirectory()`
      // reports `/var/folders/…` while the same directory canonicalizes to
      // `/private/var/folders/…`. Listing one spelling only would deny the
      // other, which fails closed but confusingly.
      for spelling in [trimmed, PathConfinement.canonicalize(trimmed)]
      where seen.insert(spelling).inserted {
        roots.append(spelling)
      }
    }
    return roots
  }()

  /// URL schemes the `url.open` capability may hand to LaunchServices.
  /// Mirrors `OpenTargetValidator`'s default `allowedURLSchemes` so the
  /// policy grant and the adapter agree on one list rather than two.
  public static let allowedURLSchemes: [String] = ["http", "https", "mailto"]
}
