'use strict';

const statusElement = document.getElementById('status');

chrome.runtime.sendMessage({ type: 'aura.bootstrap' }).then((response) => {
  const isAccepted = response && response.status === 'accepted';
  statusElement.textContent = isAccepted
    ? 'Chrome is connected to AURA.'
    : 'AURA could not establish the local bridge.';
  document.body.dataset.state = isAccepted ? 'connected' : 'failed';
}).catch(() => {
  statusElement.textContent = 'AURA could not establish the local bridge.';
  document.body.dataset.state = 'failed';
});
