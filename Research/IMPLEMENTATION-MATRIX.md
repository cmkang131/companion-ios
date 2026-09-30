# 공개 요구와 실제 구현 대조

작성: 2026-10-01 KST. 기준 안정 소스: `58d9ef8311663acf8ca427fa55d8f2b18154af62`,
증거 문서: `e8afca70b87ae945c870a31a41a903c6a078b7af`. 이 체크포인트는
`recovery/safe-follow-up`에 보존하며 후속 구현은 `recovery/task-controls`에서 진행한다.

Muse/dot 공개 설명은 제품이 지향하는 행동의 근거다. 이 앱의 기능·계정 권한·서버
호환성의 증거는 아니다. 아래의 “구현”은 생산 코드 경로가 있다는 뜻이며 실서버
검증을 뜻하지 않는다. 최신 `99ba308`의 105 integration / 5 core 테스트도 macOS의 controlled
fake 경계 검증이다. `Validation/controls-99ba308/manifest.json`에 정상 빌드·실행·10개
원본 렌더와 9개 원문 로그를 귀속했다. iOS 실기기·실서버·실제 탭 조작은 검증하지 못했다.

## 요구-구현 matrix

| 공개 요구 / 근거 종류 | 현재 구현과 사용자 진입 | 부족한 점 / 차단 분류 | 이번 후속 범위 |
|---|---|---|---|
| 지속 대화, 다른 일을 기다리지 않고 입력 — 공식 설명 | MIT OpenClawChatUI의 timeline, session 전환, 별도 draft/첨부/reply 및 send ledger. compact composer와 대화 목록 | **서버·제품 의미**: 여러 대화의 실행과 한 대화에서 동시에 보내기는 다름. upstream blocking-run 정책을 임의 해제하지 않음. draft는 메모리 보관이라 프로세스 종료까지 보장 못함 | 안정된 데이터 보존 경로 유지 |
| 캐릭터와 상태 capsule — 공식 홍보 화면 | 파란 원본 코드 캐릭터, 검정 눈·bump·glass name pill. 실제 owned response 상태와 연동. correlated nonempty final만 “응답 도착” | **검증**: live 상태 전환/실제 OS Reduce Motion 미검증. 응답 도착은 요청 성취·전달 완료가 아님 | capsule을 실제 현재 대화 활동 화면으로 연결 |
| 진행·활동·동시 작업 — 공식 설명 | `sessions.list`, `chat.history`, `agent`/`chat` 및 session events. 서버 `progressCard.get`와 `progressCard.changed`, upstream legacy progress fallback. chat 안에 진행 카드 재사용 | **앱 통합**: global `audit.activity.list` 미연결. 대화별 run metadata는 전체 durable task 모델이 아님. 결과 검증·외부 delivery 필드 없는 응답을 완료 업무로 표시할 수 없음 | 현재 대화의 실행·진행·질문 접근을 한 곳에 모음. 임의 퍼센트/가짜 작업 행 없음 |
| 중단·취소·복구 — 공식 설명 | 실제 `chat.abort(sessionKey, runId)` RPC 상속. 기존 pending cleanup은 terminal/history 처리에 의존 | **해결한 기존 앱 결함**: `try?` 실패 무시, 새 draft로 stop 진입 소실, mutable route의 late 요청. 새 activity와 per-run lease로 보완; live 취소 전파는 미검증 | 최우선: 독립 stop 진입, 정확 run/route 소유권, 요청/서버 접수/종료 확인/실패·불확실을 구분. 취소는 이미 수행한 외부 행동의 rollback이 아님 |
| 질문·명시적 결정 — 공식 설명 | 실제 `question.list/get/resolve`, requested/resolved events 및 native question cards. skip은 `question.resolve(cancel:true)` | **검증**: 권한·만료·중복·late response 경합의 앱 경계 검증 부족. 질문을 결제/실행 승인으로 표현하면 안 됨 | 두 번째: 기존 질문 응답·건너뛰기·서버 확인 경계 검증, 발견한 lifecycle 결함 최소 수정 |
| 실행·구매·접근 승인 — 공식 설명 | 현재 연결은 `operator.read/write`. 생성된 approval 데이터 타입은 있지만 `exec/plugin/openclaw.approval.*` adapter/event/UI 통합 없음 | **추가 권한 + 앱 통합 + 실서버**: `operator.approvals` 및 action/scope/expiry 검증 필요. 정책 변경은 admin 영역 | 권한을 늘리거나 허수 승인 버튼을 추가하지 않음 |
| browser preview·takeover·return control — 공식 설명/홍보 화면 | connected inline widget resolver만 구현. 이것은 원격 browser 소유권 제어가 아님 | **별도 backend 계약 + 권한 + 앱 통합**: viewing/control ownership/credential handoff의 안전한 계약 미연결 | 지원한다고 표시하지 않음 |
| 첨부와 결과물 — 공식 설명/홍보 화면 | 기존 attachment picker/staging/encoding, 연결된 상태에서 입력 가능. ready bytes와 reply snapshot 복구. managed output metadata 표시. connected widget resolver | **앱 통합**: `artifacts.download` encoder/type은 있으나 실제 managed media loader는 false/nil. **실서버**: file 수용/생성/다운로드 검증 없음 | 사용불가 이유 표시 유지. 로컬 경로나 fixture를 다운로드 성공으로 표시하지 않음 |
| 모델 설정 / 실패 복구 — 앱 설계 | 기존 upstream controls를 설정으로 이동. 취소·late signin context·catalog refresh fenced. 명시적 복원만 허용, 재연결 자동 재전송 없음 | **검증**: 실제 sheet dismiss/반복 tap·계정 흐름 미검증 | 회귀 유지, 이번 작업에서 credential 흐름 실행 안 함 |
| 음성·통화 중 채팅 — 공식 설명 | 지원하지 않음; dummy microphone 없음 | **별도 오디오 adapter + 권한 + 시스템 interruption 검증** | 범위 밖 |
| 목표·지속 작업·일정·proactivity — 공식 설명 | 대화별 server run 정보만 있음. 목표·일정·push 모델/UI 없음 | **backend 계약 + 앱 통합**: iOS가 지속 agent 실행을 대신할 수 없음. server durable execution과 event reconciliation/알림 필요 | 장식용 탭·로컬 가짜 스케줄 생성 안 함 |
| 기억 검토·수정·삭제 — 공식 설명 | 별도 메모리 관리 없음. endpoint token 삭제/연결 해제와 메모리 삭제는 다름 | **backend 계약 + 데이터 범위 결정** | disconnect를 잊기/삭제로 표현하지 않음 |
| 접근성·간결한 native UI — Apple 지침/원본 설계 | light only, native sheet/form/menu, 큰 글씨 welcome safearea, compact editor, 문자 상태, Reduce Motion/Transparency 코드 분기 | **검증**: Simulator content size 렌더만 확인. 실제 VoiceOver·OS Reduce Motion·키보드 조작/시트 반복은 blocked XCTest와 구분 필요 | 새 activity도 native List, text state, 큰 글씨 actual render 포함 |

## 고정 OpenClaw 계약과 권한

대상 upstream: `ebe57ef28af64c073de8264c7052ce519f1fda23` (MIT).
`IOSGatewayChatTransport`는 `OpenClawChatGatewayTransport`를 준수한다.
일반 `OpenClawChatTransport`의 unsupported default만 보고 기능을 판단하면 안 된다.
공용 gateway extension이 실제 abort와 question RPC를 제공한다.

- 목록/history/artifact는 read, `chat.abort`·`agent.wait`는 write 영역이다.
- question은 기본 `operator.questions` 외 session-write 대안이 있고 `operator.write`가
  이를 포함한다. 개별 질문의 세션 소유/공유 조건은 서버가 추가 검사한다.
- exec/plugin/openclaw approval은 `operator.approvals`, approval 정책 설정은 admin이다.
- 현재 요청 scope를 넓히거나 새 credential을 만들지 않는다.

공식 pinned 근거:
[core method descriptors](https://github.com/openclaw/openclaw/blob/ebe57ef28af64c073de8264c7052ce519f1fda23/src/gateway/methods/core-descriptors.ts),
[method scope alternatives](https://github.com/openclaw/openclaw/blob/ebe57ef28af64c073de8264c7052ce519f1fda23/src/gateway/method-scopes.ts),
[scope compatibility](https://github.com/openclaw/openclaw/blob/ebe57ef28af64c073de8264c7052ce519f1fda23/src/shared/operator-scope-compat.ts),
[audit handler](https://github.com/openclaw/openclaw/blob/ebe57ef28af64c073de8264c7052ce519f1fda23/src/gateway/server-methods/audit.ts),
[event list](https://github.com/openclaw/openclaw/blob/ebe57ef28af64c073de8264c7052ce519f1fda23/src/gateway/server-methods-list.ts).

앱 근거 파일: `ConnectionStore.swift`, `Upstream/IOSGatewayChatTransport.swift`,
vendored `ChatGatewayTransport.swift`, `ChatGatewayRequest.swift`, `ChatTransport.swift`,
`ChatGatewayPayloadCodec.swift`, `ChatViewModel+ProgressCard.swift`, `ChatQuestionCard.swift`.

## 검증 계획과 판정 경계

중단은 fake transport의 지연·거절·중복·다중 run·세션 전환·route 변경·누락/foreign/late
terminal을 생산 model/adapter에 통과시켜 검증한다. 접수 ACK만으로 stopped를 만들지 않는다.
새 draft/첨부/reply는 중단 요청으로 지우지 않는다. 질문도 production card/model을 사용하고
이미 해결된 질문에 늦은 응답이 UI 상태를 되돌리지 않는지 확인한다.

독립 소스 리뷰 후 보완한 구체적 계약:

- A의 중단 접수를 기다리는 동안 새 B가 나타나면 A를 재요청하지 않고 B만 중단한다.
  A/B의 원래 route lease와 종료 증거는 별도로 유지한다.
- 질문 건너뛰기는 RPC 완료만으로 확정하지 않는다. 고정 schema의 `status: cancelled`
  응답을 검증하고, 빈/다른 상태 응답은 미확인으로 처리한 뒤 질문 상태를 다시 조회한다.
- 먼저 도착한 서버 terminal 기록과 로컬 시간 만료를 구분한다. 실제 서버 terminal을 늦은
  mutation 응답으로 바꾸지 않되, 로컬 만료만 있던 질문은 확정 서버 응답으로 복구할 수 있다.
- 질문 mutation도 물리 route와 question authority를 고정한다. 같은 연결의 대화 전환은
  원래 질문에 대한 정상 답변 완료를 허용하고, route 교체·detach 뒤 늦은 응답은 차단한다.
- 세션을 지정하지 않은 질문은 “대화가 지정되지 않은 질문”으로 분리한다. 질문 객체와
  작성 중인 답변은 보존하며, 현재 대화의 요청이라고 추정하지 않는다.

`99ba308b5f02911072d76dc5ad76d3b08834b3dd`에서 macOS tests, 정상 iOS build,
privacy snapshot 검사와 native fixture renders를 완료했다. nil/빈 문자열/공백 질문은
미지정으로 동일 처리하며 세션 전환 뒤에도 범위를 추정하지 않는 회귀를 통과했다. 각 raw log에 commit과 snapshot 귀속을 남기고 manifest에
파일 hash·실행 모드·제약을 연결한다. fixture는 서버 미연결 표시를 유지하며 live 성공으로
제시하지 않는다. 실제 UI 조작은 자동화 초기화 timeout 때문에 미검증이다. 동일 실패를
장시간 반복하지 않는다.

제품 연구: [Muse 공식 설명](https://introducing.muse.ai/),
[dot 공식 문서](https://learn.chatgpt.com/docs/dots/),
`Research/MUSE-DOT-EVIDENCE.md`에 전달된 관찰·공식 주장·제안 설계 구분을 따른다.
