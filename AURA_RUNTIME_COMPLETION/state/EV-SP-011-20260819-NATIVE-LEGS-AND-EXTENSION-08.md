# EV-SP-011-20260819-NATIVE-LEGS-AND-EXTENSION-08

## Record

- **Prompt / gap:** SP-011 / OPEN-06 (R5 productivity live acceptance)
- **Timestamp:** 2026-08-19T09:55:06Z
- **Branch / commit:** `main`; `HEAD == origin/main == 33688e2a54f1e5d53574d0ddea22d5256eec29c7` at the start of this attempt
- **Working tree:** `dirty_expected`; the existing SP-010/SP-011 changes were preserved and extended. No reset, clean, or checkout occurred.
- **Environment:** macOS 27.0 (26A5416b) on Apple Silicon; Xcode 27.0 beta 5 toolchain; Safari 27.0; user-present session with full computer-use authority granted in the turn.
- **Evidence class:** direct user-present product/TCC/system-log evidence plus deterministic source-side regression.

## Objective, assumptions, risks, and acceptance criteria

- **Objective:** close the SP-011 legs that `EV-SP-011-20260819-LIVE-GMAIL-CLOSEOUT-07` left open — live calendar and contacts acceptance with real TCC interaction, and a real Safari Web Extension package and trust path.
- **Assumptions:** the calendar and contacts fixtures are disposable; the user's own address book must not enter any evidence record.
- **Risks:** a permission prompt that never appears being mistaken for a denial; an empty read being mistaken for a successful one; the extension appearing packaged while Safari never loads it; private calendar or contact content reaching a record.
- **Acceptance criteria:** each native leg raises its real macOS prompt carrying AURA's own usage string, reaches `ready` only after consent, and returns a read bound to a known fixture; the Safari extension is a real signed bundle the system registers at the Safari web-extension point.

## Symptoms and root causes

Four separate defects made three legs of the matrix **unrunnable**, not merely failing. Each was found by attempting the leg, not by reading the source.

1. **The system prompts could never be raised.** `EventKitCalendarReadAdapter.requestReadAccess()` and `ContactsFrameworkLookupAdapter.requestReadAccess()` had no production caller anywhere in the app, while the health rows told the user to "Grant Calendar access during Setup". No such Setup control existed. The same defect held for the browser row: `AuraKernel.connectBrowserProfile` had existed since SP-009 with no caller, under the remediation "Connect the Safari profile in Setup". Three remediations named controls that did not exist.

2. **The prompt was refused by policy even once it was requested.** With the grant action wired, tccd denied the request without displaying anything. The system log names the cause exactly: `Prompting policy for hardened runtime; service: kTCCServiceCalendar requires entitlement com.apple.security.personal-information.calendars but it is missing for accessing={ai.aura.local.agent}` followed by `Policy disallows prompt ...; access to kTCCServiceCalendar denied`. `Resources/AURA.entitlements` carried the Hardened Runtime audio-input key but not the calendars or addressbook resource-access keys. Its own comment had classified the missing keys as App Sandbox keys that "do not belong on this non-sandboxed executable" — true for the microphone and user-selected-file keys it discusses, wrong for these two.

3. **The app bundle could not legally show the prompt either.** `Resources/AURA-Info.plist` had no `NSCalendarsFullAccessUsageDescription` and no `NSContactsUsageDescription`, so the request would have terminated the app rather than prompting.

4. **The Safari extension had no native half and was never packaged.** `SafariBridgeNativeMessageHandler` documented itself as "the testable core of the Safari app-extension entry point" and named a `SafariWebExtensionHandler` shim that was never written; `scripts/build-app-bundle.sh` copied no extension into the bundle. The producing half of the bridge did not exist, so the containing app validated an envelope nothing could place, and `browser.read` could not reach `ready` on any real Mac.

## Direct changes

- `Sources/AuraSafariExtensionHandler/` — the missing native half, as a SwiftPM executable whose `main.swift` calls `NSExtensionMain` directly (SwiftPM has no entry-point setting). It re-encodes Safari's message and delegates to the existing validated `SafariBridgeNativeMessageHandler`, and echoes a status word only — no page text, URL, title, secret, or envelope field crosses back into the web context.
- `Resources/AuraSafariExtension-Info.plist` / `.entitlements`, `scripts/build-app-bundle.sh`, `scripts/codesign-adhoc.sh` — assemble and sign `AURA.app/Contents/PlugIns/AuraSafariExtension.appex`, extension before app so the app's signature seals it.
- `Resources/AURA.entitlements` — added `com.apple.security.personal-information.calendars` and `...addressbook`, with the tccd message recorded in the comment.
- `Resources/AURA-Info.plist` — added the calendar and contacts usage descriptions.
- `Sources/AURA/ProductivityRuntime.swift`, `AuraKernel_Productivity.swift`, `AuraAppModel_ProductState.swift`, `AuraMenuView_Tabs.swift`, `ProductUIState.swift` — a `canGrantAccess` snapshot state, `requestNativeAccess`, `grantNativeIntegrationAccess`, `connectConfiguredBrowserProfile`, and the two buttons that make all three remediations reachable. `canGrantAccess` is true only for a composed leg that is still `notDetermined`; after a decision the row points at System Settings, because macOS shows the prompt once.
- `Sources/AuraCore/Configuration_ProductivityConfiguration.swift` — `defaultSafariSharedContainerPath`. Safari refuses an unsandboxed web extension, so the extension's home is its own container; the unsandboxed app reads that absolute path. The previous empty default resolved to the process working directory.
- `Sources/AuraCore/AuraConfigurationLoading.swift` — the acceptance profile now composes calendar, contacts and the Safari bridge from their own variables. It previously composed mail only, so it could not exercise the matrix it exists for.

## Direct live procedure and result

1. Built and signed `AURA.app` with the packaged extension using the stable local identity, and installed it to `/Applications` (the previous build was parked, not deleted). `codesign --verify --deep --strict` passed.
2. **Extension registration:** with the App Sandbox entitlement in place, `pluginkit -m -p com.apple.Safari.web-extension` lists `ai.aura.local.agent.SafariExtension(0.1.0)`, `Parent Bundle = /Applications/AURA.app`, `SDK = com.apple.Safari.web-extension`. Without that entitlement the same query returned `(no matches)` — the extension is genuinely registered at Safari's extension point, not merely present on disk.
3. **Grant controls:** the Privacy & Memory tab now shows `Connect Safari profile`, and `Grant access` on the Read Calendar and Find Contact rows. All three were absent before this attempt.
4. **Calendar, denied-before-fix:** clicking `Grant access` produced no prompt and no state change; the tccd log recorded the missing-entitlement refusal quoted above.
5. **Calendar, after the entitlement fix:** the real macOS prompt appeared, titled "Allow "AURA" to access your calendar?", carrying AURA's own Info.plist string. `Allow Full Access` was clicked. The row moved to **Connected / This Mac / Ready**, and the grant button disappeared, matching the once-only prompt semantics.
6. **Contacts:** the real prompt appeared with AURA's contacts usage string and was allowed. The row moved to **Connected / This Mac / Ready**, and the app reported "Find Contact access granted."
7. **Live calendar read, empty:** a typed "what do i have today" turn routed to `calendar.read` and answered "Nothing is scheduled in that range. [source ac-7adf9a57e111]" with a trace pair, spoken to completion.
8. **Live calendar read, non-empty:** one disposable fixture event was created through the Calendar app under a separate user-present authorization prompt. The same typed turn then answered **"1 event(s): AURA SP-011 acceptance fixture [source ac-7adf9a57e111]"**. The empty-to-one transition on an unchanged query is what distinguishes a genuine EventKit read from a permission-shaped empty result.
9. **Cleanup:** the fixture event was deleted (`deleted|1`). No calendar or contact content other than the fixture's own title appears anywhere in this record.

## Deterministic verification

- `./scripts/aura-test.sh /tmp/aura-sp011-full-20260819` — **21/21 bundles, 1035/1035 tests, 0 failed**; `AURAIntegrationTests` 59/59, `AuraProductivityTests` 55/55. Log SHA-256 `586e778f19d0b59fb3bbdb19998e03b6c0cedf0bac31f6693f16314a50c1b8c6`.
- New suite `Tests/AURAIntegrationTests/SP011LiveAcceptanceReadinessTests.swift` — nine cases covering the grant-action state machine across all five authorization states, the refusal for a leg with no system permission, the Safari connect/revoke transition, the acceptance profile's per-leg composition and allowed-host parsing, the two usage-description keys, the extension's entry point and sandbox entitlement, the container-path agreement between the extension's relative path and the app's default, and the extension-before-app signing order.
- `python3 scripts/validate_second_pass_program.py`, `validate_runtime_completion.py --ci`, `validate_repo_hygiene_program.py --ci`, `validate_repo_hygiene_supply_chain.py --ci` — all exit 0.
- `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` — **38/38 passed**.
- **Post-commit regression caught and fixed.** Tracking the previously untracked
  `SP010ProviderAccountTests.swift` exposed a synthetic `ghp_`-shaped fixture to
  `validate_repo_hygiene_supply_chain.py`, which failed with two unallowlisted
  findings. The literal is deliberate — the assertion is that `boundedText`
  scrubs a real token shape — so it was marked with the policy's exact
  `REPO_HYGIENE_SECRET_FIXTURE: github_token` marker and allowlisted by exact
  path and pattern, matching the six existing fixtures.
- **iCloud conflict copies removed.** The repository lives on a synced Desktop,
  and committing files iCloud was mid-sync produced 22 `Name 2.swift`-style
  copies. SwiftPM globs `Sources/**/*.swift`, so each one redeclared every type
  in its file and broke the build. All 22 were verified byte-identical to (or an
  older snapshot of) their tracked counterparts before deletion, and `.gitignore`
  now excludes the pattern so the hazard cannot recur silently.

## Artifacts

- `/Applications/AURA.app/Contents/MacOS/AURA` — SHA-256 `464e83ef59d4e09cc02d5b0179b198f0a3b22eeff576bb8eb735c9001eb13c92`
- `/Applications/AURA.app/Contents/PlugIns/AuraSafariExtension.appex/Contents/MacOS/AuraSafariExtensionHandler` — SHA-256 `7ed4fe4a5cacb144a230b1a9338ac9ac7dcc7cc1e500f0f125724eb8b3588bb5`
- Classification: locally signed source-parity regression artifacts. **Not** Developer ID signed, notarized, or release artifacts.

## Falsifier

This result is falsified if a calendar or contacts read succeeds while the corresponding authorization is `notDetermined` or `denied`; if the grant button appears on a row macOS has already decided; if the agenda answer is not bound to the exact fixture event; if `pluginkit` stops listing the extension at Safari's web-extension point for an installed build; if any private calendar or contact content appears in a product output or record; or if the extension's native half writes an envelope the containing app's authenticated transport accepts without a valid version, identity, profile, nonce, freshness and tag.

## Scope, limitations, and verdict

- **Calendar leg:** passed live, including the denied-then-granted transition and a fixture-bound non-empty read.
- **Contacts leg:** authorization passed live and the capability reports ready. No non-empty contacts read was performed **by choice**: the only contacts on this machine are the user's own, and this prompt forbids recording real private account data. A disposable contact fixture was attempted through three routes (Contacts AppleScript, an unbundled tool, and a separately signed helper app) and each was refused by TCC or hung, so the non-empty read remains unproven.
- **Safari leg:** the package and trust path are proven as far as the system will go without a user credential. The extension is built, signed, sandboxed and registered at Safari's web-extension point. Enabling it additionally requires Safari's `Allow unsigned extensions` toggle, which raises a Touch ID / password authentication sheet ("Safari is trying to allow unsigned extensions"). That credential was deliberately not supplied. The live approved-page summary, the browser injection-ignore leg, and the browser profile revocation therefore remain unexecuted. A Developer ID signature plus notarization would remove the toggle requirement entirely and is the correct production answer.
- **Session end:** the machine's screen locked partway through, which ended UI automation. The remaining legs need an unlocked screen.
- **Mutation/send:** still explicitly excluded. Draft mail and event draft are mutation-class and no such path exists in the product.
- **Canonical SP-011 verdict:** **blocked, not completed.** Four defects that made the matrix unrunnable are fixed and two more legs now pass live, but the approved-page summary through real Safari native messaging is still unproven, and that leg is named directly in the prompt's procedure. SP-012 is not safe to start.
- **Next safe action:** with the screen unlocked, authenticate Safari's `Allow unsigned extensions`, enable "AURA Safari Read Bridge" in Safari Settings › Extensions, click `Connect Safari profile` in AURA, click the extension's toolbar button on an approved page, then run the approved-page summary, the injection-ignore leg, and the browser revoke. Do not start SP-012.
