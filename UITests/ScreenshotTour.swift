import XCTest

/// Walks the whole app and saves one PNG per screen, so a developer without a
/// device or simulator handy can review the layout. Never fails because a
/// screen is missing (the app evolves); only fails if the app itself never
/// gets past onboarding or `--skip-onboarding` never reaches the home screen.
final class ScreenshotTour: XCTestCase {
    private let timeout: TimeInterval = 10
    private var counter = 0
    private var skipped: [String] = []
    private var crashed: [String] = []
    private var outputDir: URL?

    override func setUp() {
        continueAfterFailure = true
        if let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            outputDir = url
        }
    }

    override func tearDown() {
        if !skipped.isEmpty { print("SKIPPED: \(skipped.joined(separator: ", "))") }
        if !crashed.isEmpty { XCTFail("App crashed on: \(crashed.joined(separator: ", "))") }
    }

    func testCaptureEveryScreen() {
        let onboarding = XCUIApplication()
        onboarding.launchArguments = ["--reset-onboarding"]
        onboarding.launch()
        walkOnboarding(onboarding)
        onboarding.terminate()

        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        guard app.buttons["Mes Apps"].waitForExistence(timeout: timeout) else {
            XCTFail("Home screen never appeared with --skip-onboarding")
            return
        }
        walkMainApp(app)
    }

    // MARK: Onboarding

    private func walkOnboarding(_ app: XCUIApplication) {
        let heading = app.staticTexts["onboarding.heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: timeout), "Onboarding never appeared")
        let primary = app.buttons["onboarding.primary"]

        shoot(app, "onboarding-welcome")
        primary.tap()

        shoot(app, "onboarding-name")
        let nameField = app.textFields["onboarding.name"]
        if nameField.waitForExistence(timeout: timeout) { nameField.tap(); nameField.typeText("Adrien\n") }
        primary.tap()

        shoot(app, "onboarding-hours")
        primary.tap()

        shoot(app, "onboarding-projection")
        primary.tap()

        shoot(app, "onboarding-goals")
        let goal = app.buttons["Mieux dormir"]
        if goal.waitForExistence(timeout: timeout) { goal.tap() }
        primary.tap()

        shoot(app, "onboarding-essentials")
        primary.tap()

        shoot(app, "onboarding-unlock")
        primary.tap()

        shoot(app, "onboarding-hardmode")
        primary.tap()

        shoot(app, "onboarding-challenge")
        primary.tap()

        shoot(app, "onboarding-rules")
        primary.tap()

        shoot(app, "onboarding-permissions")
    }

    // MARK: Main app (--skip-onboarding)

    private func walkMainApp(_ app: XCUIApplication) {
        shoot(app, "home")

        let profile = app.buttons["home.settings"]
        if profile.waitForExistence(timeout: timeout) {
            profile.tap()
            _ = app.descendants(matching: .any).matching(identifier: "home.profileMenu").firstMatch.waitForExistence(timeout: timeout)
            shoot(app, "profile-menu")
            // Tap the scrim above the menu to close it.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.12)).tap()
        } else {
            skipped.append("profile-menu")
        }

        walkAppsTab(app)
        walkTimerTab(app)
        walkSettings(app)
    }

    private func walkAppsTab(_ app: XCUIApplication) {
        let tab = app.buttons["Mes Apps"]
        guard tab.waitForExistence(timeout: timeout) else { skipped.append("apps-tab"); return }
        tab.tap()
        _ = app.buttons["apps.newRule"].waitForExistence(timeout: timeout)
        shoot(app, "apps-tab")

        let newRule = app.buttons["apps.newRule"]
        guard newRule.waitForExistence(timeout: timeout) else { skipped.append("apps-new-rule-sheet"); return }
        newRule.tap()
        shoot(app, "apps-new-rule-sheet")
        closeSheet(app)
    }

    private func walkTimerTab(_ app: XCUIApplication) {
        let tab = app.buttons["Minuteur"]
        guard tab.waitForExistence(timeout: timeout) else { skipped.append("timer-tab"); return }
        tab.tap()
        shoot(app, "timer-tab")

        let start = app.buttons["timer.start"]
        guard start.waitForExistence(timeout: timeout) else { skipped.append("commit-sheet"); return }
        start.tap()
        guard app.buttons["commit.hold"].waitForExistence(timeout: timeout) else { skipped.append("commit-sheet"); return }
        shoot(app, "commit-sheet")
        closeSheet(app)
    }

    /// Relaunches straight into the settings: driving the profile menu proved flaky.
    private func walkSettings(_ app: XCUIApplication) {
        app.terminate()
        app.launchArguments = ["--skip-onboarding", "--open-settings"]
        app.launch()
        guard app.descendants(matching: .any).matching(identifier: "settings.waitingRoom").firstMatch.waitForExistence(timeout: timeout) else {
            skipped.append("settings-root"); return
        }
        shoot(app, "settings-root")

        visit(app, name: "settings-waiting-room", element: app.descendants(matching: .any).matching(identifier: "settings.waitingRoom").firstMatch)
        visit(app, name: "settings-autofocus", label: "Autofocus")
        visit(app, name: "settings-shields", label: "Écrans de blocage")
        visit(app, name: "settings-notifications", label: "Notifications")
        visit(app, name: "settings-account", label: "Mon compte")
        visit(app, name: "settings-apps-distracting", label: "Distrayantes")
        visit(app, name: "settings-emergency-ticket", label: "Pass d’urgence")
        visit(app, name: "settings-support-chat", label: "Discuter avec l’assistance")
        visit(app, name: "settings-help", label: "Centre d’aide")
        visit(app, name: "settings-doors", label: "Mes portes")

        // Paywall, reached from the "Essayer Seuil Pro" button on the settings hero card.
        restartIfNeeded(app, before: "paywall")
        let pro = app.buttons["settings.tryPro"]
        if pro.waitForExistence(timeout: 4) {
            pro.tap()
            if app.buttons["paywall.cta"].waitForExistence(timeout: timeout) {
                shoot(app, "paywall")
                app.buttons["paywall.close"].tap()
            } else {
                skipped.append("paywall")
            }
        } else {
            skipped.append("paywall")
        }

        let done = app.buttons["Terminé"]
        if done.waitForExistence(timeout: timeout) { done.tap() }

        // Doors gallery, opened from the home hero.
        let hero = app.buttons["home.hero"]
        if hero.waitForExistence(timeout: timeout) {
            hero.tap()
            shoot(app, "doors-gallery")
            app.buttons["Fermer"].firstMatch.tap()
        } else {
            skipped.append("doors-gallery")
        }
    }

    private func visit(_ app: XCUIApplication, name: String, label: String) {
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        visit(app, name: name, element: row)
    }

    private func visit(_ app: XCUIApplication, name: String, element: XCUIElement) {
        restartIfNeeded(app, before: name)
        guard element.waitForExistence(timeout: timeout) else { skipped.append(name); return }
        element.tap()
        shoot(app, name)
        guard app.state == .runningForeground else { crashed.append(name); return }
        goBack(app)
    }

    /// A screen that crashes the app must not cost us every screen after it:
    /// relaunch straight back into the settings and carry on.
    private func restartIfNeeded(_ app: XCUIApplication, before name: String) {
        guard app.state != .runningForeground else { return }
        app.launchArguments = ["--skip-onboarding", "--open-settings"]
        app.launch()
        _ = app.descendants(matching: .any).matching(identifier: "settings.waitingRoom").firstMatch.waitForExistence(timeout: timeout)
    }

    /// Sheets close from their own button; a swipe often lands on a scroll view.
    private func closeSheet(_ app: XCUIApplication) {
        let close = app.buttons["Fermer"].firstMatch
        if close.waitForExistence(timeout: 2) { close.tap() } else { app.swipeDown() }
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.buttons["Retour"]
        if back.waitForExistence(timeout: 2) {
            back.tap()
        } else if app.navigationBars.buttons.count > 0 {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    /// Saves a PNG to SCREENSHOT_DIR, falling back to an always-kept XCTAttachment.
    private func shoot(_ app: XCUIApplication, _ name: String) {
        // Let animations and async loads settle so no frame is caught half drawn.
        Thread.sleep(forTimeInterval: 0.8)
        counter += 1
        let fileName = String(format: "%02d-%@.png", counter, name)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        var wrote = false
        if let dir = outputDir {
            wrote = (try? data.write(to: dir.appendingPathComponent(fileName))) != nil
        }
        if !wrote {
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = fileName
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
