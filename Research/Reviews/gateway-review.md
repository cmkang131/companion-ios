# Gateway integration review

Review date: 2026-09-30. Scope: `ConnectionStore`, endpoint validation, adapted iOS transport, and the relevant vendored gateway/chat lifecycle APIs. Static review only; no build, Simulator, network connection, credential access, or server change was performed by this reviewer. Line numbers describe the version inspected and may move during remediation.

## Findings

1. **P1 — A pending connection can save a token after the user deletes it.** `ConnectionStore.connect` captures `rememberToken` at line 74 and uses that captured value to save at lines 96–99. `forgetToken` deletes and resets the preference at lines 162–169, but does not invalidate that save. The delete button remains enabled during connection (`CompanionApp`, line 136). Reproduction sequence: enable token storage, connect to a slow gateway, delete the stored token before the handshake returns, then let the handshake succeed. The captured token is stored again. Minimum repair: invalidate a storage-consent revision when deletion is requested; check generation, consent revision, and current opt-in immediately before saving. Disable deletion during connection as additional UI protection, or keep it available and make revocation authoritative.

2. **P2 — Normal authentication failures receive the wrong recovery instructions.** `ConnectionStore.connectionError` (lines 198–208) recognizes only `GatewayResponseError`. The actual connect rejection is constructed as `GatewayConnectAuthError` (`GatewayChannel`, lines 899–919) and preserved through the catch/rethrow path (lines 367–381). Invalid-token and pairing-required errors therefore fall through to advice to check address, certificate, and network. Reuse `GatewayConnectionProblemMapper.map(error:)` and translate its typed `kind` to appropriate Korean recovery text. Do not display raw server-controlled commands or arbitrary technical text as instructions.

3. **P2 — Retrying a failed connection discards the unsent composer draft.** `ConnectionStore.connect` detaches and releases the model at lines 70–71, including on a retry to the same endpoint. `OpenClawChatViewModel.input` and `draftsBySession` are in-memory model state (lines 22 and 37); the constructed model has no persistence adapter. A user who typed a long draft, lost network, and pressed retry loses the draft before the retry succeeds. Preserve the current draft and canonical session in memory for a retry to the same normalized endpoint; never restore it into another endpoint or another session. Explicit disconnection can keep its separately documented clearing behavior.

4. **P2 — History results and loading state are not owned by individual requests.** `loadHistory` (lines 172–185) checks the connection generation but has no request identity. Two loads in the same generation can finish in reverse order, with the older result/error replacing a newer success and either request clearing the spinner while the other remains pending. `connect` also clears sessions without clearing `transport`, `historyError`, or `isLoadingHistory`; an old-generation request's defer intentionally cannot clear that loading state. Minimum repair: a history-request identity and a consistent history reset on connection replacement/disconnect; ignore cancelled requests and require the intended route to be usable before starting a load.

5. **P2 — Character working motion survives loss of connection.** `CompanionApp` line 44 maps `pendingRunCount > 0` directly to `.thinking`. `didDisconnect` leaves the model intact, and upstream deliberately preserves an unresolved run when observation is unavailable (`ChatViewModel+TransportEvents`, lines 1376–1382). Consequently a disconnected client can continue displaying working motion although it cannot currently verify progress. Gate the presentation by connection availability and show a neutral/connection-checking state while disconnected. Do not clear the underlying pending run merely to stop the animation: the server may still be executing it.

## Route and credential observations

- The adapted modern send path acquires a route, tests routing/settings capabilities, and uses a route-fenced request. A proven pre-dispatch route replacement is mapped to `notDispatched`; this protection should be retained.
- A new `GatewayNodeSession` per connection and the app generation checks protect callbacks from an explicitly replaced endpoint. Upstream serializes lifecycle callbacks. After awaiting the main-session key, an additional check that the captured physical route is still current would prevent creating a model from an invalidated route and guessed fallback key; this is a hardening recommendation rather than a reproduced user-facing failure.
- `allowStoredDeviceAuth: false` with `deviceAuthGatewayID: nil` disables upstream device-token lookup and persistence (`GatewayConnectOptions`, lines 103–108). The separate persisted device identity is still created when `includeDeviceIdentity` is true; first real connection therefore remains an explicit credential-creation approval point for this task.
- Endpoint validation requires HTTPS/WSS, rejects URL user/password, query/fragment, whitespace and invalid ports. The connection uses system TLS validation. This review found no app code that puts the supplied gateway token into UserDefaults or logs it directly. This is not an exhaustive audit of every vendored log path.

## Regression verification needed

The five current integration tests cover input validation, an empty disconnect, a transport send without any gateway, and session-key resolution. They do not exercise a real/fake successful handshake, delayed callbacks, credential persistence, or history concurrency. Their execution was not performed or claimed by this reviewer.

Recommended deterministic tests using a thin injected lifecycle/keychain boundary around the existing implementation:

- delayed success after token deletion must not save;
- pairing/token/protocol errors produce distinct recovery guidance;
- cancelled or replaced connection cannot publish a model, save credentials, or update history;
- old history success/error finishing after a new result has no effect;
- same-endpoint retry preserves the draft in its original session; another endpoint receives no old draft;
- pending run plus disconnect displays uncertain connectivity, then resumes only after connection is established.

Actual gateway authentication, message dispatch/streaming, reconnection, permissions and server-side state still require integration verification against an approved gateway. None is established by this static review.

## Remediation readback

The main implementation owner subsequently changed the code. An independent second static read confirmed:

- The token save checks the current connection generation, storage-consent revision and current opt-in; requesting deletion invalidates the revision before attempting the keychain deletion. There is no suspension between the final checks and the keychain save on the main actor.
- Structured connect errors now go through `GatewayConnectionProblemMapper`. Three parameterized test cases were added for pairing, token mismatch and protocol mismatch. Their runtime result was not evaluated by this reviewer.
- Reconnection retains the current text draft and session only for the same normalized endpoint, including across an unsuccessful retry. A different endpoint and explicit disconnect clear the retained draft. Upstream `load`/`startBootstrap` does not immediately clear the restored input.
- Connection replacement resets the transport and history state. Each history load owns a request UUID, so an older completion or defer cannot replace the latest request's result or loading state.
- Working motion now requires `connection.canSend`; disconnected presentation is paused without destroying unresolved server-run ownership.

No additional confirmed regression was found in these changes. The earlier physical-route revalidation recommendation remains: after `waitForCurrentMainSessionKey` suspends, check the captured route again before using its key or fallback to construct the model. A missing key due to route retirement should not be treated as a configured default.

This second pass did not run builds, Simulator, tests, keychain mutations or gateway requests. Credential-revocation, delayed-history and draft-retry behavior still need deterministic regression execution and later approved live integration QA.
