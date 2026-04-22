const colorInput = document.getElementById("highlightColor");
const saveBtn = document.getElementById("saveBtn");
const statusEl = document.getElementById("status");

function loadOptions() {
  chrome.storage.sync.get({ highlightColor: "#fff59d" }, (items) => {
    colorInput.value = items.highlightColor;
  });
}

function saveOptions() {
  chrome.storage.sync.set({ highlightColor: colorInput.value }, () => {
    statusEl.textContent = "저장 완료";
    setTimeout(() => {
      statusEl.textContent = "";
    }, 1200);
  });
}

saveBtn.addEventListener("click", saveOptions);
document.addEventListener("DOMContentLoaded", loadOptions);

