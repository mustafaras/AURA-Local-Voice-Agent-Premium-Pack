# R10 Privilege Topology — First-Pass Baseline

This is a source-backed baseline, not an assertion that all boundaries are
already OS-enforced.

| Process/domain | Current authority | Intended authority | Current status |
| --- | --- | --- | --- |
| `AURA` | UI, runtime, audio, policy, model, shell, Accessibility/screen paths | UI/consent/presentation plus runtime planning/state | Main process remains non-sandboxed; privilege concentration is open |
| `AuraAutomationHelper` | App Sandbox entitlement; typed echo/attestation target | Accessibility/Apple Events/ScreenCapture/generated-input executor only | Product exists; production executor wiring and authenticated IPC are open |
| `AuraShellHelper` | App Sandbox entitlement; typed echo/attestation target | Scoped shell/agent CLI executor with directory/network/budget limits | Product exists; production executor wiring and authenticated IPC are open |
| `AuraPluginHost` | App Sandbox entitlement; digest-pinned plugin launch path | Isolated plugin execution with manifest grants and bounded I/O | Helper path and supply-chain checks exist; catalog/update PKI remains open |
| `AuraAgent`/Ollama | Main-process adapter and loopback URLSession | Runtime planning only; network client through mandatory endpoint policy | Loopback and API-path policy first slice is implemented; DNS/provider breadth remains open |

## Boundary rules

- Models and external content propose data; they do not choose capability,
  target, scope, recipient, secret, or confirmation outcome.
- Policy authorizes an immutable plan before a helper or adapter executes it.
- The helper envelope binds helper kind, actor, capability, target, plan hash,
  payload hash, freshness, and nonce. The caller owns replay state.
- `sandboxAttested` is an assertion from the helper and is not by itself proof
  of a valid code signature; the caller must verify the helper digest/signature.
- A pipe created by a parent process is not equivalent to XPC peer identity.
  No external-beta claim may rely on this baseline until peer authentication
  or an independently reviewed equivalent is wired and tested.
