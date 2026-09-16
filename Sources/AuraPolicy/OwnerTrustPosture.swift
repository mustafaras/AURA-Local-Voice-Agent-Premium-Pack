import Foundation

/// The owner trust posture of this local build (ADR-064, PA-0).
///
/// The release owner directed that AURA is a personal assistant on a single,
/// password-protected Mac: the macOS login is the authentication boundary,
/// and inside it the assistant must never ask twice. When `isEnabled` is
/// true, every seeded grant in `DefaultPolicyGrants` resolves to
/// `confirmationRequirement: .none`, and the computer-use structural guards
/// (`ComputerUseGuardPosture.production`) and the screen-context
/// sensitive-application exclusion are lifted. The policy engine still
/// evaluates and audits every call; only its *answer* for the owner changes.
///
/// This is a compile-time constant, not a runtime toggle, on purpose: a
/// toggle is one more thing to be asked about, and a persisted toggle could
/// be flipped by a copied store. Flipping it to `false` restores the
/// pre-PA-0 posture — the eight challenging seeds and every guard — with no
/// other change; `OwnerTrustPostureTests` proves the switch is the only
/// difference.
///
/// ADR-064 boundary: this is an owner-instructed, **non-transferable** local
/// risk acceptance under ADR-049 (local-only, no Developer ID, no external
/// distribution). It is not a product default. A build that ships
/// `isEnabled == true` to another user or device falsifies ADR-064. The
/// emergency stop is the owner's explicit exception and is never derived
/// from this value.
public enum OwnerTrustPosture {
  /// Whether the owner posture is in force for this build. See the type
  /// documentation and ADR-064 before changing this value.
  public static let isEnabled = true
}
