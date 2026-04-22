# SMLEE Extension

Chrome Extension Manifest V3 기준 최소 템플릿입니다.

## 포함 기능

1. `popup`에서 버튼 클릭으로 현재 페이지 하이라이트 토글
2. `options` 페이지에서 하이라이트 색상 저장
3. `content script`에서 DOM 스타일 적용
4. `background service worker` 초기 설정값 준비

## 폴더 구조

```text
Sm_Chrome_Extension/
  manifest.json
  background.js
  content/
    content.js
  popup/
    popup.html
    popup.css
    popup.js
  options/
    options.html
    options.css
    options.js
```

## 실행 방법

1. Chrome에서 `chrome://extensions` 열기
2. `개발자 모드` ON
3. `압축해제된 확장 프로그램 로드`
4. `Sm_Chrome_Extension` 폴더 선택
5. 임의 웹페이지에서 확장 아이콘 클릭 후 버튼 테스트

## 참고

- `chrome://`, `chrome web store` 등 일부 페이지에서는 content script가 동작하지 않습니다.
- 배포 시에는 `manifest.json` 버전 갱신 후 ZIP 패키징해서 업로드하면 됩니다.
