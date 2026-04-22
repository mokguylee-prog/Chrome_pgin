# Chrome 플러그인(확장 프로그램) 구조 가이드

이 문서는 Chrome Extension **Manifest V3(MV3)** 기준으로,
"플러그인이 어떤 구조로 동작하는지"를 빠르게 이해할 수 있게 정리한 설명서입니다.

## 1) 전체 구조 한눈에 보기

Chrome 플러그인은 보통 아래 구성요소로 나뉩니다.

1. `manifest.json`
2. `background`(MV3에서는 `service_worker`)
3. `content_scripts`
4. UI 페이지(`popup`, `options`, 필요 시 `side_panel`)
5. 정적 리소스(아이콘, 이미지, CSS/JS 파일)

간단 흐름:

1. 브라우저가 `manifest.json`을 읽어 플러그인 권한/엔트리를 등록
2. 이벤트가 발생하면 `service_worker`가 깨어나 로직 실행
3. 웹페이지 조작이 필요하면 `content_script`가 탭 DOM에 접근
4. 사용자 클릭(툴바 아이콘 등) 시 `popup` UI가 열리고 스크립트 실행
5. 컴포넌트 간에는 메시지(`runtime.sendMessage`)로 통신

## 2) 핵심 파일 역할

### `manifest.json`
- 플러그인의 "설정 파일"이자 진입점
- 이름, 버전, 권한, 실행 스크립트, 아이콘, popup 페이지 등을 정의
- MV3에서는 `background.service_worker`를 사용

### `background/service_worker.js`
- 항상 켜져 있는 프로세스가 아니라, **이벤트 기반으로 실행**
- 설치/업데이트, 알림 클릭, 탭 이벤트, 메시지 수신 등 백그라운드 업무 담당
- 긴 작업은 알람(`chrome.alarms`)이나 상태 저장과 함께 설계하는 것이 안정적

### `content_scripts`
- 실제 웹페이지 DOM에 접근해 읽기/수정
- 예: 특정 사이트 버튼 숨기기, 텍스트 추출, 하이라이트
- 페이지 컨텍스트에서 동작하므로, 백그라운드와는 메시지로 연결

### `popup.html` + `popup.js`
- 확장 아이콘 클릭 시 뜨는 작은 UI
- 짧은 사용자 상호작용(토글, 현재 탭 정보 표시 등)에 적합
- 페이지가 닫히면 팝업 스크립트도 종료됨(지속 실행 아님)

### `options.html` + `options.js`
- 사용자 설정 화면
- API 키, 동작 옵션, 사이트별 설정 등을 `chrome.storage`에 저장

## 3) 통신 구조(중요)

컴포넌트는 분리되어 있으므로 메시지 설계가 핵심입니다.

1. `popup` -> `service_worker`
2. `service_worker` -> `content_script`
3. `content_script` -> `service_worker`

주요 API:

- 단발 메시지: `chrome.runtime.sendMessage`, `chrome.tabs.sendMessage`
- 지속 연결: `chrome.runtime.connect` (Port)

권장:

1. 메시지 타입(`type`)을 고정 문자열로 관리
2. 요청/응답 데이터 스키마를 명확히 정의
3. 에러 응답 포맷도 통일

## 4) 권한(Permissions) 이해

`manifest.json`의 권한은 최소 권한 원칙으로 설계합니다.

- `permissions`: 탭, 스토리지, 알람 등 API 권한
- `host_permissions`: 접근 가능한 URL 범위
- `activeTab`: 사용자가 액션을 일으킨 현재 탭에 임시 권한

권한이 넓을수록 심사/신뢰 측면에서 불리할 수 있으니, 필요한 것만 선언합니다.

## 5) 저장소(Storage) 선택

- `chrome.storage.local`: 로컬 기기 저장(용량 여유, 동기화 없음)
- `chrome.storage.sync`: 계정 기반 동기화(용량 제한 주의)
- `chrome.storage.session`: 세션 메모리성 데이터

설정값은 보통 `sync`, 캐시/로그는 `local`을 많이 사용합니다.

## 6) 기본 폴더 예시

```text
my-extension/
  manifest.json
  service-worker.js
  content-script.js
  popup/
    popup.html
    popup.js
    popup.css
  options/
    options.html
    options.js
  assets/
    icon16.png
    icon48.png
    icon128.png
```

## 7) 최소 `manifest.json` 예시(MV3)

```json
{
  "manifest_version": 3,
  "name": "My Chrome Plugin",
  "version": "0.1.0",
  "description": "Example extension structure",
  "action": {
    "default_popup": "popup/popup.html"
  },
  "background": {
    "service_worker": "service-worker.js"
  },
  "permissions": ["storage", "activeTab", "scripting"],
  "host_permissions": ["https://*/*", "http://*/*"],
  "content_scripts": [
    {
      "matches": ["https://*/*", "http://*/*"],
      "js": ["content-script.js"]
    }
  ],
  "icons": {
    "16": "assets/icon16.png",
    "48": "assets/icon48.png",
    "128": "assets/icon128.png"
  }
}
```

## 8) 개발/실행 흐름

1. 파일 작성
2. Chrome `chrome://extensions` 진입
3. 개발자 모드 ON
4. "압축해제된 확장 프로그램 로드"로 폴더 선택
5. 수정 후 새로고침(또는 재로드)하면서 테스트

## 9) 처음 설계할 때 체크리스트

1. 핵심 기능이 DOM 조작 중심인지, 백그라운드 자동화 중심인지 구분
2. 어떤 권한이 정말 필요한지 먼저 확정
3. 메시지 타입/응답 포맷을 초기에 고정
4. 저장 전략(`sync/local`)을 먼저 정해 데이터 구조를 안정화
5. MV3 서비스 워커의 "이벤트 기반 실행" 특성을 반영해 상태 관리

---

필요하면 다음 단계로, 이 구조 그대로 동작하는 **실행 가능한 초기 템플릿 코드**까지 바로 만들어서 붙여드릴 수 있습니다.
