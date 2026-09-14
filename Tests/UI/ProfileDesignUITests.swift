import XCTest

/// Run against the separately built and installed app. All launches use SampleProductService.
final class ProfileDesignUITests: XCTestCase {
    @MainActor func testSingleIntroductionAction() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.campus.social")
        app.launchArguments = ["-sample", "-profile", "Duru", "-AppleLanguages", "(tr)"]
        app.launch()
        let action = app.buttons["profile.introduction"]
        XCTAssertTrue(action.waitForExistence(timeout: 20))
        for _ in 0..<8 where !action.isHittable { app.swipeUp() }
        XCTAssertTrue(action.isHittable)
        XCTAssertTrue(action.label.contains("Tanışmak isterim"))
        action.tap()
        let disabled = NSPredicate(format: "enabled == false")
        expectation(for: disabled, evaluatedWith: action)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(action.label.contains("gönderildi"))
        XCTAssertFalse(app.textViews.firstMatch.exists)
    }

    @MainActor func testPaywallPlansAndLegalAccess() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.campus.social")
        app.launchArguments = ["-sample", "-paywall", "-AppleLanguages", "(tr)"]
        app.launch()
        let plus = app.buttons["paywall.plan.plus"]
        let pro = app.buttons["paywall.plan.pro"]
        XCTAssertTrue(plus.waitForExistence(timeout: 20))
        XCTAssertTrue(plus.isSelected)
        pro.tap()
        XCTAssertTrue(pro.isSelected)
        XCTAssertFalse(plus.isSelected)
        XCTAssertTrue(app.buttons["paywall.purchase"].label.contains("PRO"))
        XCTAssertTrue(app.buttons["paywall.privacy"].isHittable)
        XCTAssertTrue(app.buttons["paywall.restore"].isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Paywall standard"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["paywall.terms"].tap()
        XCTAssertTrue(app.buttons["Bitti"].waitForExistence(timeout: 8))
        app.buttons["Bitti"].tap()
        plus.tap()
        XCTAssertTrue(plus.isSelected)
        app.buttons["paywall.close"].tap()
        XCTAssertFalse(plus.exists)
    }

    @MainActor func testProfileHomeMembershipAndEditing() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.campus.social")
        app.launchArguments = ["-sample", "-tab", "profile", "-AppleLanguages", "(tr)"]
        app.launch()
        XCTAssertTrue(app.buttons["profile.edit"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["profile.visitors"].exists)
        XCTAssertTrue(app.buttons["profile.ghost"].exists)
        XCTAssertFalse(app.buttons["profile.photoDeck"].exists)
        app.buttons["profile.ghost"].tap()
        XCTAssertTrue(app.buttons["Kapat"].waitForExistence(timeout: 8))
        app.buttons["Kapat"].firstMatch.tap()
        app.buttons["profile.edit"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 8))
        app.terminate()
        app.launchArguments += ["-tier", "pro"]
        app.launch()
        XCTAssertTrue(app.switches["profile.ghost"].waitForExistence(timeout: 20))
        let ghost = app.switches["profile.ghost"]
        let before = ghost.value as? String
        ghost.tap()
        XCTAssertNotEqual(ghost.value as? String, before)
        app.buttons["profile.settings"].tap()
        XCTAssertTrue(app.buttons["Bitti"].waitForExistence(timeout: 8))
    }

    @MainActor private func profile(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.campus.social")
        app.launchArguments = ["-sample", "-profile", "Ece", "-profile-swipe-preview", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["profile.photoDeck"].waitForExistence(timeout: 20), app.debugDescription)
        return app
    }

    @MainActor func testProfileRequestAndPhotoGesturesAreSeparate() {
        let app = profile()
        let deck = app.buttons["profile.photoDeck"]
        let start = deck.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 55, dy: 0)))
        XCTAssertFalse(app.staticTexts["Test isteği gönderildi"].exists)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 155, dy: 0)))
        XCTAssertTrue(app.staticTexts["Test isteği gönderildi"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Testi sıfırla"].exists)
        app.buttons["Testi sıfırla"].tap()
        let before = deck.label
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -100, dy: 0)))
        XCTAssertNotEqual(deck.label, before)
        XCTAssertFalse(app.staticTexts["Test isteği gönderildi"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Profile photo deck"; attachment.lifetime = .keepAlways; add(attachment)
        deck.tap()
        XCTAssertTrue(app.buttons["Kapat"].waitForExistence(timeout: 5))
        app.buttons["Kapat"].firstMatch.tap()
    }

    @MainActor func testFailedRequestCanRetryAndNeverShowsSuccess() {
        let app = profile(["-preview-request-fails"])
        let deck = app.buttons["profile.photoDeck"]
        for _ in 0..<2 {
            let start = deck.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 155, dy: 0)))
            XCTAssertTrue(app.staticTexts["Test bağlantısı kesildi. Yeniden deneyebilirsin."].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Test isteği gönderildi"].exists)
        }
    }

    @MainActor func testOwnProfileSettingsAndEditorRemainReachable() {
        let app = XCUIApplication(bundleIdentifier: "com.campus.social")
        app.launchArguments = ["-sample", "-tab", "profile", "-AppleLanguages", "(tr)"]
        app.launch()
        XCTAssertTrue(app.buttons["profile.settings"].waitForExistence(timeout: 20))
        app.buttons["profile.settings"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Profile settings"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertTrue(app.navigationBars.count > 0)
    }
}
