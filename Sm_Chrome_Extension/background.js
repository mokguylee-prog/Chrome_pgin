chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.sync.get({ highlightColor: "#fff59d" }, (items) => {
    if (!items.highlightColor) {
      chrome.storage.sync.set({ highlightColor: "#fff59d" });
    }
  });
});

function getTimestamp() {
  const now = new Date();
  const pad2 = (value) => String(value).padStart(2, "0");
  const pad3 = (value) => String(value).padStart(3, "0");

  return [
    now.getFullYear(),
    pad2(now.getMonth() + 1),
    pad2(now.getDate())
  ].join("") +
    "_" +
    [
      pad2(now.getHours()),
      pad2(now.getMinutes()),
      pad2(now.getSeconds()),
      pad3(now.getMilliseconds())
    ].join("");
}

chrome.downloads.onDeterminingFilename.addListener((item, suggest) => {
  const isFromThisExtension = item.byExtensionId === chrome.runtime.id;
  if (!isFromThisExtension) {
    suggest();
    return;
  }

  const isPng = (item.mime || "").toLowerCase() === "image/png";
  const isDataCapture = (item.url || "").startsWith("data:image/png");
  if (!isPng && !isDataCapture) {
    suggest();
    return;
  }

  const filename = `smlee-capture-${getTimestamp()}.png`;
  suggest({ filename, conflictAction: "uniquify" });
});
