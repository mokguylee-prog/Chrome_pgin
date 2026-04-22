chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.sync.get({ highlightColor: "#fff59d" }, (items) => {
    if (!items.highlightColor) {
      chrome.storage.sync.set({ highlightColor: "#fff59d" });
    }
  });
});

