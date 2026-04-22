const STYLE_ID = "simple-extension-highlight-style";
const CLASS_NAME = "simple-extension-highlight";

function getHighlightColor() {
  return new Promise((resolve) => {
    chrome.storage.sync.get({ highlightColor: "#fff59d" }, (items) => {
      resolve(items.highlightColor || "#fff59d");
    });
  });
}

function ensureStyle(color) {
  let style = document.getElementById(STYLE_ID);
  const css = `
    .${CLASS_NAME} body {
      box-shadow: inset 0 0 0 6px ${color};
      transition: box-shadow 0.2s ease;
    }
  `;

  if (!style) {
    style = document.createElement("style");
    style.id = STYLE_ID;
    document.documentElement.appendChild(style);
  }

  style.textContent = css;
}

async function toggleHighlight() {
  const color = await getHighlightColor();
  ensureStyle(color);
  document.documentElement.classList.toggle(CLASS_NAME);
  return document.documentElement.classList.contains(CLASS_NAME);
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "TOGGLE_HIGHLIGHT") {
    return false;
  }

  toggleHighlight()
    .then((enabled) => sendResponse({ ok: true, enabled }))
    .catch((error) => sendResponse({ ok: false, error: String(error) }));

  return true;
});

