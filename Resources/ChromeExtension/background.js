// AURA Chrome Read Bridge — background service worker.
//
// Read-only. The extension-owned bootstrap page may publish an empty handshake
// when the user chooses Connect Chrome in AURA. Web-page text is read only when
// the user clicks the toolbar button. There is no polling or background page
// capture, and cookies, passwords, and hidden page state are never read.
//
// The native host validates the message and signs it into the shared container
// with the same ECDSA P-256 key the AURA app pins when the user connects the
// profile, so nothing here is trusted by itself.

const AURA_MESSAGE_TYPE = "aura.activeTabObservation";
const AURA_BOOTSTRAP_TYPE = "aura.bootstrap";
const AURA_PROTOCOL_VERSION = 1;
const AURA_EXTENSION_ID = "com.aura.safari-extension";
const AURA_PROFILE_ID = "personal";

// Bounded observation size, mirrored by SafariBridgeEnvelopeWriter.
const MAX_VISIBLE_TEXT = 20000;

// The native messaging host name registered in Chrome's NativeMessagingHosts
// directory. It must match the host manifest's "name" field exactly.
const AURA_HOST_NAME = "ai.aura.local.agent";

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

  let visibleText = "";
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: readVisibleText,
      args: [MAX_VISIBLE_TEXT]
    });
    const first = Array.isArray(results) ? results[0] : undefined;
    visibleText =
      first && typeof first.result === "string" ? first.result : "";
  } catch {
    // Protected local pages cannot be injected. The explicit user action may
    // still publish the key with URL/title metadata and bounded empty text.
  }

  await sendObservation(tab, visibleText);
}

async function sendObservation(tab, visibleText) {
  if (!tab || typeof tab.id !== "number" || !tab.url) {
    return;
  }

  return chrome.runtime.sendNativeMessage(AURA_HOST_NAME, {
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

chrome.action.onClicked.addListener((tab) => {
  // Fail closed: a failed read is dropped, never retried and never queued.
  // The app sees the absence as an unavailable or stale bridge.
  sendActiveTabObservation(tab).catch(() => {});
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const bootstrapURL = `chrome-extension://${chrome.runtime.id}/bootstrap.html`;
  if (
    !message ||
    message.type !== AURA_BOOTSTRAP_TYPE ||
    sender.id !== chrome.runtime.id ||
    sender.url !== bootstrapURL ||
    !sender.tab ||
    typeof sender.tab.id !== "number"
  ) {
    return false;
  }

  const bootstrapTab = {
    id: sender.tab.id,
    url: sender.url,
    title: sender.tab.title || "AURA Chrome Read Bridge"
  };
  sendObservation(bootstrapTab, "").then(
    (reply) => sendResponse({
      status: reply && reply.status === "accepted" ? "accepted" : "rejected"
    }),
    () => sendResponse({ status: "rejected" })
  );
  return true;
});
