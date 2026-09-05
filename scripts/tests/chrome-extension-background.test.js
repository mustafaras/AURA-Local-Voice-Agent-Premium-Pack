'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const backgroundSource = fs.readFileSync(
  path.join(__dirname, '../../Resources/ChromeExtension/background.js'),
  'utf8'
);

function loadActionListener({ document, executeScript, sendNativeMessage }) {
  let actionListener;
  let messageListener;
  const chrome = {
    action: {
      onClicked: {
        addListener(listener) {
          actionListener = listener;
        },
      },
    },
    runtime: {
      id: 'ggccnafnholmbpghgljfbofapcbhkdjh',
      onMessage: {
        addListener(listener) {
          messageListener = listener;
        },
      },
      sendNativeMessage,
    },
    scripting: { executeScript },
  };

  vm.runInNewContext(backgroundSource, { chrome, document });
  assert.equal(typeof actionListener, 'function');
  return { actionListener, messageListener };
}

test('publishes an empty bounded observation when page injection is refused', async () => {
  let resolveMessage;
  const messageSent = new Promise((resolve) => {
    resolveMessage = resolve;
  });
  const { actionListener } = loadActionListener({
    executeScript: async () => {
      throw new Error('Cannot access a protected page');
    },
    sendNativeMessage: async (hostName, message) => {
      resolveMessage({ hostName, message });
      return { status: 'accepted' };
    },
  });

  actionListener({ id: 7, url: 'about:blank', title: '' });
  const sent = await messageSent;

  assert.equal(sent.hostName, 'ai.aura.local.agent');
  assert.equal(sent.message.tab.url, 'about:blank');
  assert.equal(sent.message.tab.visibleText, '');
});

test('publishes visible text from an injectable page', async () => {
  let resolveMessage;
  const messageSent = new Promise((resolve) => {
    resolveMessage = resolve;
  });
  const { actionListener } = loadActionListener({
    document: { body: { innerText: 'x'.repeat(20001) } },
    executeScript: async ({ args, func }) => [{ result: func(...args) }],
    sendNativeMessage: async (_hostName, message) => {
      resolveMessage(message);
      return { status: 'accepted' };
    },
  });

  actionListener({ id: 8, url: 'https://example.com/', title: 'Example' });
  const message = await messageSent;

  assert.equal(message.tab.visibleText, 'x'.repeat(20000));
  assert.equal(message.tab.title, 'Example');
});

test('publishes an empty observation from the extension-owned bootstrap page', async () => {
  let resolveMessage;
  const messageSent = new Promise((resolve) => {
    resolveMessage = resolve;
  });
  const { messageListener } = loadActionListener({
    executeScript: async () => {
      throw new Error('bootstrap must not inspect page content');
    },
    sendNativeMessage: async (_hostName, message) => {
      resolveMessage(message);
      return { status: 'accepted' };
    },
  });

  assert.equal(typeof messageListener, 'function');
  const keepsChannelOpen = messageListener(
    { type: 'aura.bootstrap' },
    {
      id: 'ggccnafnholmbpghgljfbofapcbhkdjh',
      url: 'chrome-extension://ggccnafnholmbpghgljfbofapcbhkdjh/bootstrap.html',
      tab: {
        id: 9,
        title: 'AURA Chrome Read Bridge',
      },
    },
    () => {}
  );
  const message = await messageSent;

  assert.equal(keepsChannelOpen, true);
  assert.equal(message.tab.visibleText, '');
  assert.equal(message.tab.tabID, '9');
});

test('reports a native host rejection instead of claiming connection', async () => {
  let bootstrapResponse;
  const responseSent = new Promise((resolve) => {
    bootstrapResponse = resolve;
  });
  const { messageListener } = loadActionListener({
    executeScript: async () => [],
    sendNativeMessage: async () => ({ status: 'unauthorized' }),
  });

  const keepsChannelOpen = messageListener(
    { type: 'aura.bootstrap' },
    {
      id: 'ggccnafnholmbpghgljfbofapcbhkdjh',
      url: 'chrome-extension://ggccnafnholmbpghgljfbofapcbhkdjh/bootstrap.html',
      tab: { id: 10, title: 'AURA Chrome Read Bridge' },
    },
    bootstrapResponse
  );

  assert.equal(keepsChannelOpen, true);
  assert.equal((await responseSent).status, 'rejected');
});

test('rejects bootstrap messages from any other sender URL', () => {
  let nativeCalls = 0;
  const { messageListener } = loadActionListener({
    executeScript: async () => [],
    sendNativeMessage: async () => {
      nativeCalls += 1;
      return { status: 'accepted' };
    },
  });

  const keepsChannelOpen = messageListener(
    { type: 'aura.bootstrap' },
    {
      id: 'ggccnafnholmbpghgljfbofapcbhkdjh',
      url: 'https://example.com/',
      tab: { id: 11, title: 'Example' },
    },
    () => {}
  );

  assert.equal(keepsChannelOpen, false);
  assert.equal(nativeCalls, 0);
});