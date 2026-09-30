import XCTest

@MainActor
final class CompanionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["connectionButton"].waitForExistence(timeout: 15))
        return app
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWelcomeSettingsValidationAndRepeatedDismissal() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["여기 있어요"].exists)
        screenshot("01-welcome")
        app.buttons["connectionButton"].tap()
        XCTAssertTrue(app.textFields["endpointField"].waitForExistence(timeout: 5))
        screenshot("02-connection-settings")
        let field = app.textFields["endpointField"]
        field.tap()
        field.typeText("http://example.com\n")
        app.swipeUp()
        let submit = app.buttons["connectSubmit"]
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        let error = app.staticTexts["connectionError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("HTTPS"))
        app.swipeDown()
        screenshot("03-insecure-address-error")
        app.buttons["완료"].tap()
        for _ in 0..<2 {
            app.buttons["historyButton"].tap()
            XCTAssertTrue(app.staticTexts["아직 연결하지 않았어요"].waitForExistence(timeout: 5))
            screenshot("04-disconnected-history")
            app.buttons["완료"].tap()
            app.buttons["connectionButton"].tap()
            XCTAssertEqual(app.textFields["endpointField"].value as? String, "http://example.com")
            app.buttons["완료"].tap()
        }
    }

    func testPreviewTranscriptAndHistory() {
        let app = launch(["--ui-preview"])
        XCTAssertTrue(app.staticTexts["미리보기 · 서버 미연결"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "오늘은 조금")).firstMatch.waitForExistence(timeout: 10))
        let composer = app.otherElements["chat-composer-surface"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertLessThan(composer.frame.height, 90, "Default-size resting composer should stay compact")
        XCTAssertFalse(app.buttons["chat-message-actions"].exists)
        XCTAssertFalse(app.staticTexts["Default"].exists)
        screenshot("05-preview-transcript")
        app.buttons["historyButton"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "천천히 시작하는 하루")).firstMatch.waitForExistence(timeout: 10))
        screenshot("06-preview-history")
        app.buttons["완료"].tap()
    }

    func testUnavailableArtifactExplainsMissingCapability() {
        let app = launch(["--ui-preview", "--ui-artifact-preview"])
        XCTAssertTrue(app.staticTexts["검증용 메모.pdf"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["이 연결에서는 첨부 파일을 열 수 없어요."].exists)
        XCTAssertFalse(app.buttons["Download"].exists)
        screenshot("09-artifact-capability-unavailable")
    }

    func testLargeTextAndKeyboard() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["connectWelcomeButton"].isHittable)
        screenshot("07-accessibility-text")
        app.buttons["connectionButton"].tap()
        let field = app.textFields["endpointField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://example.com")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        screenshot("08-accessibility-keyboard")
        app.buttons["완료"].tap()
        XCTAssertTrue(app.buttons["connectWelcomeButton"].waitForExistence(timeout: 5))
    }
}
