# ADR-030 — Stable Local Signing and Natural System TTS

- **Status:** Accepted
- **Date:** 2026-07-29
- **Partial supersession:** ADR-031 supersedes the TTS-selection decision;
  stable local signing and permission decisions remain accepted.

## Context

Ad-hoc signatures produce an unstable local code identity across rebuilds.
macOS TCC grants can consequently appear lost after replacing the development
app. The system TTS fallback also defaulted to `en-US` and assigned a
human-facing `1.0` rate directly to AVFoundation's absolute rate scale, which
made Turkish output select the wrong voice and speak unnaturally fast.

The target Mac has an installed premium Turkish neural voice. Chatterbox
remains a fail-closed adapter boundary and is not an operational synthesizer.

## Decision

1. Local builds prefer a self-signed, locally trusted code-signing identity
   named `AURA Stable Local Signing` from the login Keychain.
2. Machines without that identity fall back to ad-hoc signing. The identity is
   strictly a local development mechanism; it is not Developer ID and does not
   satisfy notarization or distribution requirements.
3. Both the isolated plugin helper and main app use the selected identity,
   Hardened Runtime, and their existing least-privilege entitlements.
4. The system TTS fallback defaults to `tr-TR`, ranks installed exact-locale
   voices by AVFoundation quality, and deterministically selects the best
   available voice.
5. A configured speech-rate multiplier of `1.0` maps to the platform default
   speech rate. Lower and higher multipliers remain bounded by AVFoundation's
   supported range.
6. Human perceptual acceptance of the new voice is an explicit manual gate and
   is not inferred from unit or integration tests.
7. Screen Recording onboarding calls the supported
   `CGRequestScreenCaptureAccess` API before relying on the manual System
   Settings route, ensuring that the stable-signed app is registered with TCC.

## Consequences

- TCC grants can persist across rebuilds that retain the bundle identifier and
  local certificate identity.
- Installing the stable identity changes the app identity once, so macOS may
  request consent again on the first stable-signed launch.
- Turkish output uses the best installed local voice and a natural baseline
  rate without transmitting transcript text.
- Certificate loss, expiry, or re-creation changes the identity and requires a
  new TCC consent cycle.
- Developer ID signing and notarization remain release gates.

## Rejected alternatives

- Writing directly to the TCC database: rejected because it bypasses macOS
  consent and security controls.
- Hard-coding one voice identifier: rejected because voice installations differ
  across Macs.
- Representing Chatterbox as active: rejected because the adapter remains a
  non-operational boundary prototype.
