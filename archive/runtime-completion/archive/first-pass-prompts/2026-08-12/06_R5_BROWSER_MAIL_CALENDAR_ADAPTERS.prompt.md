# R5 — Browser, Mail, Calendar, and Contacts Adapters Prompt

Execute after R3. R4 may proceed separately, but computer use must remain a fallback rather than the primary productivity integration.

## Mission

Deliver practical personal-assistant workflows through structured, least-privilege adapters for browser, mail, calendar, and contacts. Roll out read-only capabilities first. Add mutations and sending only after draft/review, bound confirmation, injection defenses, and independent verification are complete.

## Required context

Read:

- capability registry/planner and confirmation contracts;
- policy, network allowlist, prompt-injection classifier, Keychain/secret facilities;
- store, task, memory/context, and UI integration interfaces;
- official current documentation for selected browser, Apple/Google mail, calendar, contacts, OAuth, and Keychain APIs;
- ADR-040 proposal;
- relevant privacy and threat-model sections.

Do not assume browser or provider APIs from memory. Verify current interfaces and scopes.

## Integration priority

For each workflow use:

1. native framework/provider API;
2. official structured protocol/extension/CLI/Shortcuts integration;
3. Accessibility;
4. screen/computer use as explicit fallback.

Document why each selected mechanism is the safest reliable option.

## Browser adapter

Implement typed capabilities for the selected supported browser(s):

- open URL/search query;
- list/focus/close approved tabs;
- active-tab metadata;
- read approved visible/page text through a structured integration;
- back/forward/reload;
- summarize page with provenance;
- fill non-sensitive forms;
- click semantic controls;
- download to an approved directory;
- cancel and inspect progress.

Requirements:

- explicit browser/profile scope;
- no cookie/session/password extraction;
- no hidden page-script authority;
- redirects/domains checked by enforced network policy;
- authentication, payment, permission, upload, publish, delete, and purchase boundaries require confirmation or refusal;
- page content is untrusted data.

## Mail adapters

Implement a provider abstraction with one or both production adapters:

- Apple Mail through verified structured mechanisms;
- Gmail through OAuth and provider API.

Read-first capabilities:

- list accounts/mailboxes approved by user;
- unread counts;
- search;
- read thread/message headers and approved bodies;
- summarize with message/thread IDs and provenance;
- attachment metadata and bounded approved download;
- mark read/archive only after mutation gates.

Compose capabilities:

- create draft;
- edit draft;
- add attachments from approved paths;
- review recipients, subject, body, and attachments;
- send only after a dedicated immutable confirmation transaction;
- verify provider message ID/send state.

Use incremental OAuth scopes. A read-only installation must not request send scope. Tokens remain in Keychain references and are immediately revocable.

## Calendar and contacts

Capabilities:

- agenda for date/range;
- search/read event;
- free/busy and conflict detection;
- draft event;
- resolve attendees through scoped contacts lookup;
- review time zone, recurrence, location, attendees, and reminders;
- create/update/delete only with appropriate confirmation;
- verify provider event ID and final state.

Do not expose the full address book to a model. Resolve only candidates needed for the current request and clarify ties.

## Trust and prompt injection

For mail, page, attachment, and event content:

- tag provenance as external/untrusted;
- isolate content from system/tool instructions;
- prevent content from selecting capabilities, weakening policy, approving actions, changing recipients, or requesting secrets;
- sanitize model context;
- validate all typed outputs;
- add direct and indirect prompt-injection fixtures.

## Offline/degraded behavior

Clearly distinguish:

- integration not configured;
- token expired/revoked;
- network unavailable;
- provider unavailable;
- scope insufficient;
- account ambiguous;
- content blocked by privacy policy.

Do not fall back to browser UI automation for account actions without explicit user selection and compatible policy.

## Tests

Required:

- OAuth scope escalation and revocation;
- Keychain reference handling and redaction;
- domain/redirect/network enforcement;
- account/profile ambiguity;
- read-only scope cannot mutate/send;
- draft review and immutable send confirmation;
- recipient/address ambiguity;
- attachment path/size/type controls;
- time-zone, recurrence, and conflict logic;
- provider error/retry/cancellation;
- exact post-action verification;
- mail/web/event prompt injection;
- secrets never enter logs/events/prompts/speech;
- computer-use fallback remains explicit and bounded.

## Live acceptance

With explicitly authorized test accounts/profiles:

1. summarize unread mail;
2. search and summarize a thread;
3. create but do not send a draft;
4. send a benign test message after reviewed confirmation, if send authority is explicitly granted;
5. show tomorrow’s agenda and free window;
6. draft/create a test event with attendee ambiguity resolution;
7. open and summarize an approved page;
8. demonstrate injection content is ignored;
9. revoke access and prove immediate disablement.

Never use real private accounts or send external messages without explicit authorization.

## Completion gate

R5 is complete only when read-first browser/mail/calendar capabilities are structured, registered, user-reachable, least-privilege, injection-resistant, privacy-visible, and live-verified; mutation/send flows are separately gated and verified or explicitly excluded from scope.

Accept ADR-040, update capability/evidence/risk/state/ledger/handoff, unblock R9/R10 dependencies, and run closeout.
