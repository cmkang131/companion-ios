// Executed by check_gateway_log_privacy.py with the real production error types.
let marker = "SYNTHETIC_SERVER_ECHO_3BC4E97A"
let echoed = "draft=\(marker) token=\(marker) wss://\(marker)@example.invalid/\(marker)"
let auth = GatewayConnectAuthError(
    message: echoed,
    detailCode: GatewayConnectAuthDetailCode.authRateLimited.rawValue,
    canRetryWithDeviceToken: false,
    recommendedNextStep: GatewayConnectRecoveryNextStep.waitThenRetry.rawValue,
    requestId: marker,
    detailsReason: marker)
let unknownAuth = GatewayConnectAuthError(
    message: echoed,
    detailCode: marker,
    canRetryWithDeviceToken: false)
let response = GatewayResponseError(
    method: marker,
    code: marker,
    message: echoed,
    details: ["reason": AnyCodable(marker), "message": AnyCodable(echoed)])
let decode = GatewayDecodingError(method: marker, message: echoed)
let arbitrary = NSError(domain: marker, code: 17, userInfo: [NSLocalizedDescriptionKey: echoed])
let network = URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: echoed, NSURLErrorKey: echoed])
let cases: [(Error, String)] = [
    (auth, "connect_auth"),
    (unknownAuth, "connect_auth"),
    (response, "gateway_response"),
    (decode, "gateway_decode"),
    (arbitrary, "other"),
    (network, "network"),
    (CancellationError(), "cancelled"),
    (GatewayNodeSessionRequestError.routeChangedBeforeDispatch, "route_changed"),
]
for (error, expected) in cases {
    let category = GatewayErrorDiagnostics.category(for: error)
    precondition(category == expected)
    precondition(!category.contains(marker))
    precondition(!"chat.send failed \(category)".contains(marker))
}
// Verify the fixtures really contain the marker; sanitization must not work by
// stripping the error object that the connection mapper and outbox depend on.
precondition(auth.localizedDescription.contains(marker))
precondition(response.localizedDescription.contains(marker))
precondition(decode.localizedDescription.contains(marker))
precondition(auth.detail == .authRateLimited && auth.isNonRecoverable)
precondition(auth.recommendedNextStep == .waitThenRetry)
precondition(auth.requestId == marker && auth.detailsReason == marker)
precondition(unknownAuth.detailCodeRaw == marker && unknownAuth.detail == nil)
precondition(response.code == marker && response.message == echoed && response.detailsReason == marker)

let scope = GatewayResponseError(
    method: "question.list", code: "FORBIDDEN", message: echoed,
    details: ["code": AnyCodable("MISSING_SCOPE"), "missingScope": AnyCodable("operator.questions"),
              "requiredScopes": AnyCodable(["operator.read", "operator.questions"])])
precondition(scope.isAuthorizationFailure && scope.missingScope == "operator.questions")
precondition(scope.missingScopeDetails?.requiredScopes == ["operator.read", "operator.questions"])
let legacyScope = GatewayResponseError(
    method: "question.list", code: "INVALID_REQUEST",
    message: "missing scope: operator.questions \(marker)", details: nil)
precondition(legacyScope.isAuthorizationFailure && legacyScope.missingScope == "operator.questions")
let legacyUnsupported = GatewayResponseError(
    method: "sessions.branches.list", code: "INVALID_REQUEST",
    message: "unknown method \(marker)", details: nil)
let legacyDenied = GatewayResponseError(
    method: "sessions.branches.list", code: "FORBIDDEN",
    message: "missing scope: operator.admin \(marker)", details: nil)
precondition(OutboxProbe.branchListingIsUnsupported(legacyUnsupported))
precondition(!OutboxProbe.branchListingIsUnsupported(legacyDenied))
let wireDetails = gatewayErrorDetails(ErrorShape(
    code: "INVALID_REQUEST", message: echoed,
    details: AnyCodable(["code": AnyCodable("MISSING_SCOPE"), "reason": AnyCodable(marker)]),
    retryable: false, retryafterms: 500))
precondition(wireDetails["code"]?.stringValue == "MISSING_SCOPE")
precondition(wireDetails["errorCode"]?.stringValue == "INVALID_REQUEST")
precondition(wireDetails["message"]?.stringValue == echoed)
precondition(wireDetails["reason"]?.stringValue == marker)
precondition(wireDetails["retryable"]?.boolValue == false && wireDetails["retryAfterMs"]?.intValue == 500)
print("PASS: synthetic remote marker excluded in 8 helper cases across 7 categories; auth, wire, scope and legacy outbox classifier checks passed")
