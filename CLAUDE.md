# CLAUDE.md

이 파일은 Claude Code(claude.ai/code)에서 이 리포지토리의 코드를 작업할 때 참고할 지침을 제공합니다.

## 프로젝트 개요

이 프로젝트는 **Chrome 확장 프로그램** 개발입니다. Chrome 확장은 manifest 기반 아키텍처를 사용하며, 백그라운드 스크립트, 콘텐츠 스크립트, 팝업 UI, 그리고 선택적 페이지들로 구성됩니다.

## 권장 폴더 구조

잘 정리된 Chrome 확장 프로젝트는 다음과 같은 구조를 사용합니다:

```
Chrome_pgin/
├── manifest.json           # 확장 매니페스트 (v3 필수)
├── public/                 # 정적 자산
│   ├── icons/
│   │   ├── icon-16.png
│   │   ├── icon-48.png
│   │   ├── icon-128.png
│   │   └── icon-256.png
│   └── popup.html          # 팝업 UI
├── src/
│   ├── background.js       # Service Worker (v3) 또는 백그라운드 스크립트 (v2)
│   ├── content.js          # 웹 페이지에 주입되는 콘텐츠 스크립트
│   ├── popup.js            # 팝업 스크립트
│   ├── styles/
│   │   └── popup.css
│   └── utils/              # 공유 유틸리티
├── tests/                  # 테스트 파일
├── package.json            # 의존성 (번들러 사용 시)
├── webpack.config.js       # (선택사항) 번들러 설정
└── README.md
```

## 주요 개발 명령어

### Chrome에서 로컬 테스트하기
1. `chrome://extensions/` 열기
2. 우측 상단의 "개발자 모드" 활성화
3. "압축 해제된 확장 프로그램 로드" 클릭 후 프로젝트 폴더 선택
4. 코드 변경 후 확장 프로그램 새로고침 (새로고침 아이콘 클릭)

### 번들러 사용 시 (대규모 확장 권장):
```bash
npm install
npm run dev        # 개발 모드 감시
npm run build      # 프로덕션용 최적화
npm run test       # 테스트 실행 (설정된 경우)
```

### 번들러 미사용 시:
- `src/`와 `public/` 폴더의 파일을 직접 수정
- Chrome 개발자 도구에서 확장 프로그램 새로고침 후 테스트

## Chrome 확장 아키텍처

### manifest.json (v3)
- 권한, 백그라운드 서비스 워커, 콘텐츠 스크립트 선언
- 팝업 및 액션 아이콘 지정
- 지속적 저장소 권한 정의

### Service Worker (background.js)
- 백그라운드에서 실행되며 확장 이벤트 리스닝
- `chrome.runtime.onMessage`로 통신 처리
- `chrome.tabs.onUpdated`로 페이지 모니터링
- `chrome.storage`로 데이터 보존

### 콘텐츠 스크립트 (content.js)
- 일치하는 웹 페이지에 주입됨
- 페이지 DOM 읽기/수정 가능
- 확장으로의 직접 접근 제한됨; `chrome.runtime.sendMessage`로 통신

### 팝업 (popup.html + popup.js)
- 확장 아이콘 클릭 시 나타나는 UI
- 백그라운드 서비스 워커와 통신 가능
- CSS로 스타일링 포함

## 중요 고려사항

- **Manifest v3**: 새 확장은 v3 사용; v2는 지원 중단. 주요 차이점:
  - `background.service_worker` (v2의 `background.scripts` 대체)
  - 스크립트에서 `eval()` 불가; 인라인 스크립트는 CSP 필요
  - 더 제한적인 권한 모델

- **권한**: 필요한 것만 요청 (보안 및 사용자 신뢰)
- **저장소**: 클라우드 동기화는 `chrome.storage.sync`, 로컬만은 `chrome.storage.local` 사용
- **메시징**: 백그라운드 ↔ 콘텐츠 통신에 `chrome.runtime.sendMessage` 사용
- **아이콘**: 모든 필수 크기 제공 (16, 48, 128, 256px)

## 자주 사용되는 패턴

### 탭 변경 감지하기
```javascript
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete') {
    // 탭 로드됨, 콘텐츠 스크립트에 메시지 전송
  }
});
```

### 콘텐츠 스크립트에서 백그라운드로 메시지 보내기
```javascript
chrome.runtime.sendMessage({ action: 'doSomething' }, response => {
  console.log(response);
});
```

### 백그라운드에서 메시지 수신하기
```javascript
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'doSomething') {
    sendResponse({ result: 'done' });
  }
});
```

## 디버깅 팁

- **백그라운드 서비스 워커 로그**: 확장 정보 → "검사 보기" → "service_worker"
- **콘텐츠 스크립트 로그**: 확장이 실행되는 페이지의 일반 DevTools 열기
- **팝업 로그**: 팝업 우클릭 → "검사"
- **확장 프로그램 새로고침**: `chrome://extensions/`에서 새로고침 아이콘 클릭
