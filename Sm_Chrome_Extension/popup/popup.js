const statusEl = document.getElementById("status");
const currentTabEl = document.getElementById("currentTab");
const toggleBtn = document.getElementById("toggleBtn");
const optionsBtn = document.getElementById("optionsBtn");

function setStatus(text) {
  statusEl.textContent = text;
}

function shortenUrl(url) {
  if (!url) return "탭 URL을 읽을 수 없습니다.";
  if (url.length <= 45) return url;
  return `${url.slice(0, 45)}...`;
}

async function getActiveTab() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  return tabs[0];
}

toggleBtn.addEventListener("click", async () => {
  setStatus("처리 중...");

  try {
    const tab = await getActiveTab();
    if (!tab?.id) {
      setStatus("활성 탭을 찾지 못했습니다.");
      return;
    }

    const response = await chrome.tabs.sendMessage(tab.id, {
      type: "TOGGLE_HIGHLIGHT"
    });

    if (!response?.ok) {
      setStatus("실패: 메시지 응답이 없습니다.");
      return;
    }

    setStatus(response.enabled ? "하이라이트 ON" : "하이라이트 OFF");
  } catch (_error) {
    setStatus("이 페이지에서는 실행할 수 없습니다.");
  }
});

optionsBtn.addEventListener("click", () => {
  chrome.runtime.openOptionsPage();
});

document.addEventListener("DOMContentLoaded", async () => {
  try {
    const tab = await getActiveTab();
    currentTabEl.textContent = shortenUrl(tab?.url);
  } catch (_error) {
    currentTabEl.textContent = "탭 정보를 읽을 수 없습니다.";
  }
});

