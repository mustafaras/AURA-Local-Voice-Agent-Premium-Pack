// AURA Safari Read Bridge — background service worker.
//
// User-gated and read-only. The user clicks the toolbar button, the extension
// reads the active tab's visible text once, and sends that single observation
// to the containing app over native messaging. Nothing is read without that
// click: there is no polling, no queue, and no background reads. It never
// reads cookies, passwords, or hidden page state, and it never executes
// arbitrary page scripts on the model's behalf.
//
// The containing app validates a signed envelope (version, extension
// identity, profile identity, nonce, freshness, and an ECDSA P-256 signature
// made by a key the app pinned when the user connected the profile) before
// any capability can consume the observation, so nothing here is trusted by
// itself.

const AURA_MESSAGE_TYPE = "aura.activeTabObservation";
const AURA_PROTOCOL_VERSION = 1;
const AURA_EXTENSION_ID = "com.aura.safari-extension";
const AURA_PROFILE_ID = "personal";

// Bounded observation size, mirrored by SafariBridgeEnvelopeWriter.
const MAX_VISIBLE_TEXT = 20000;

// Safari routes native messages to the containing app. The application
// identifier is required by the API and ignored by Safari itself.
const AURA_APP_ID = "ai.aura.local.agent";

// Runs in the page, on an explicit user gesture only. innerText reflects
// rendered text, so hidden elements and password field values are excluded.
function readVisibleText(limit) {
  const body = document.body;
  if (!body) {
    return "";
  }
  return (body.innerText || "").slice(0, limit);
}

async function sendActiveTabObservation(tab) {
  // Without a tab id and a real URL there is nothing the app can scope or
  // allowlist, so the read is refused rather than sent half-formed.
  if (!tab || typeof tab.id !== "number" || !tab.url) {
    return;
  }

  const results = await browser.scripting.executeScript({
    target: { tabId: tab.id },
    func: readVisibleText,
    args: [MAX_VISIBLE_TEXT]
  });
  const first = Array.isArray(results) ? results[0] : undefined;
  const visibleText =
    first && typeof first.result === "string" ? first.result : "";

  await browser.runtime.sendNativeMessage(AURA_APP_ID, {
    type: AURA_MESSAGE_TYPE,
    protocolVersion: AURA_PROTOCOL_VERSION,
    extensionID: AURA_EXTENSION_ID,
    profileID: AURA_PROFILE_ID,
    tab: {
      tabID: String(tab.id),
      profileID: AURA_PROFILE_ID,
      url: tab.url,
      title: tab.title || "",
      visibleText: visibleText
    }
  });
}

browser.action.onClicked.addListener((tab) => {
  // Fail closed: a failed read is dropped, never retried and never queued.
  // The app sees the absence as an unavailable or stale bridge.
  sendActiveTabObservation(tab).catch(() => {});
});
