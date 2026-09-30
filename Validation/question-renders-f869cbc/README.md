# 최신 질문 화면 검증 자료

소스: `f869cbc116c9bb553ddd54bb9d0d8e44bdc963da` · 전용 iPhone17e / iOS27 Simulator · 2026-10-01 KST.

생산 질문 권한/범위 로직은 검토된 `bf8ece6` 그대로다. 추가 코드는 DEBUG 본문 진입과 촬영 위치 지정뿐이며, 일반 normal build(`ENABLE_DEBUG_DYLIB=NO`)를 설치했다. 처음에는 소스 변경 없이 보존된 bf8ece6 앱의 두 화면을 촬영했고 `baseline-bf8ece6/`에 별도로 보존했다.

## 보고용 개별 PNG 6장

각 원본은1170×2532이며 축소된 이미지 모음 대신 개별 파일로 Library에 저장했다. 모두 합성 대화이며 `미리보기 · 서버 미연결` 표시가 있다.

| 화면 | 원본 | 확인한 내용 | Library 파일 |
|---|---|---|---|
| 기본 대화 | [compact.png](compact.png) | 회색/연파랑 버블, 간결한 composer, 미연결 미리보기 | `Companion-f869cbc-01-chat.png` · `libfile_50a7d08b7c0c81918fb42273c7ecff0e` |
| 본문 · 현재 대화 | [transcript-current.png](transcript-current.png) | 질문 답변과 실행 승인의 구분, 비활성 답변/건너뛰기 | `Companion-f869cbc-02-current-question.png` · `libfile_0f083876418c8191b7f595bea74767c9` |
| 본문 · 미지정 | [transcript-unscoped.png](transcript-unscoped.png) | 미지정 범위 설명, 연결 후 답변 안내 | `Companion-f869cbc-03-unscoped-question.png` · `libfile_ca820ba0270081919ec3c9174c3a4966` |
| 활동 · 미지정 | [questions-unscoped.png](questions-unscoped.png) | 본문과 같은 범위/연결 제한, 진행 정보의 의미 | `Companion-f869cbc-04-activity-question.png` · `libfile_f6d2b1f3619081919506a921c9cb2037` |
| 본문 · AX5 상단 | [transcript-unscoped-ax5.png](transcript-unscoped-ax5.png) | 미지정 제목과 설명 시작; 전체 설명/카드는 아래로 이어짐 | `Companion-f869cbc-05-transcript-AX5.png` · `libfile_f6e6340d14ec81918f5d8d1fc1f08747` |
| 활동 · AX5 하단 | [questions-ax5-footer.png](questions-ax5-footer.png) | 세로로 배치된 비활성 버튼과 연결 안내; 범위 제목은 위쪽 viewport | `Companion-f869cbc-06-activity-AX5.png` · `libfile_ffe2201c8da481919a904ea1ed689daa` |

[작은 두 화면 비교 이미지](Companion-f869cbc-question-comparison.png)는 본문/활동의 같은 미지정 질문을 나란히 놓았다. 원본을 자르거나 UI를 합성하지 않았다. Library: `libfile_473b33cbb8508191879ee8f2246ed525`.

추가 일반 활동 현재 대화 화면은 [questions.png](questions.png)에 보존했다. 위 여섯 장의 보고용 선정과 구분된다.

## 검증과 한계

- 최신 소스에서114 integration 함수/11 suites + core5 PASS. macOS 생산 모델과 controlled fake boundary 범위다.
- 정상 iOS 빌드·설치·실행·실제 콘텐츠 픽셀 확인. 설치/built main SHA는 `619421965f0c2716403c84dc47a040eb708dbfc52d5eee597c79c1bd0ec35570`; Core SHA도 일치한다.
- Privacy182개 소스,8 helper 사례/7분류 PASS. 실제 OSLog sink나 모든 데이터 흐름의 검증은 아니다.
- [manifest.json](manifest.json)에11개 최신 원문 로그, 각 캡처의 UTC·flags·content size·SHA, 소스/실행파일과 Library 대응을 연결했다. 모든 성공 로그에 full source hash와574개 tracked blob 일치 헤더가 있다.
- AX5 본문에서는 긴 설명/질문 전체를 한 번에 볼 수 없다. 진행 표시와 입력 초안이 화면을 차지하며 스크롤이 필요하다. 실제 스크롤 조작은 검증하지 않았다. 활동 하단은 프로그램으로 위치를 지정했다.
- 실제 탭·닫기·재열기·키보드 조작·VoiceOver·OS Reduce Motion/Transparency·live server·실기기 설치는 미검증이다. 같은 자동화 timeout을 다시 실행하지 않았다.
- `--ui-testing`에서 캐릭터는 정지한다. 이전11초 영상은 별도 idle gallery 자료이며 이번 화면의 live 전환이나 FPS 근거가 아니다.

실행/결제 승인, 브라우저 제어, 음성, 기억, 지속 작업 및 결과물 다운로드의 남은 통합 범위는 [구현 matrix](../../Research/IMPLEMENTATION-MATRIX.md)에 있다. 질문은 실행 승인과 다르다. 이번 자료는 수정된 질문 표시의 렌더 검증이며 전체 앱 완성 판정이 아니다.
