# Productivity integrations — first read-first slice

This document records the implementation boundary for R5's first source-backed
slice. It does not claim live provider acceptance or completion of R5.

## Selected mechanisms

- **Browser:** Safari Web Extension native messaging is the structured boundary.
  The Swift adapter accepts only a profile-scoped active-tab response and
  bounded visible text. It does not read cookies, passwords, hidden page state,
  or execute arbitrary page scripts. The extension target/native bridge is a
  separate packaging step and the capability remains disabled until it is
  wired into the composition root.
- **Calendar:** `EventKitCalendarReadAdapter` uses `EKEventStore` and requests
  full event access only through its explicit `requestReadAccess()` onboarding
  method. A read operation never prompts implicitly. Event titles, locations,
  and recurrence descriptions are external content and are injection-scanned.
- **Contacts:** `ContactsFrameworkLookupAdapter` uses
  `CNContactStore`/`CNContactFetchRequest` with a bounded candidate limit and
  only identifier, name, email, and phone keys. It returns candidates for the
  current query; it never produces the full address book as model context.
- **Mail:** `GmailReadAdapter` is a read-only provider adapter over a structured
  transport seam. The current reviewed Gmail read tier is
  `gmail.readonly`; compose/send scopes are separate manifest tiers and are
  rejected by the read adapter. Tokens are accessed through a Keychain-backed
  reference and removed immediately on revoke.

## Shared safety boundary

All provider hosts and browser URLs pass a `ProductivityNetworkPolicy` backed by
`NetworkAllowlist`; redirect hosts are rechecked. External page, mail, event,
attachment, and contact text uses non-authoritative `ContentProvenance` and the
existing deterministic `PromptInjectionClassifier`. Such content may be
bounded data for a summary, but can never authorize a capability, change a
target, approve a confirmation, choose recipients, or request a secret.

The four R5 read capabilities are registered in `InitialCapabilitySet` with
truthful `.disabled` availability until composition-root/UI reachability,
provider/browser configuration, and live acceptance exist. This preserves the
existing reachable-capability count and avoids claiming an integration that has
not been exercised.

## Remaining work

Provider OAuth consent/revocation with an explicitly authorized test account,
the Safari extension packaging/native bridge, runtime composition and NLU/UI
reachability, mutation/draft/send flows with immutable confirmation and
post-action verification, and the nine-scenario live acceptance remain open.

## Source references

- [Safari web extensions](https://developer.apple.com/documentation/safariservices/safari-web-extensions)
- [Safari web-extension native messaging](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
- [Accessing the EventKit event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)
- [Accessing the Contacts store](https://developer.apple.com/documentation/contacts/accessing-the-contact-store)
- [Gmail API OAuth scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
