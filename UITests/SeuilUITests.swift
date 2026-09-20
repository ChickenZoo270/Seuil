import XCTest

/// Flows that do not need Screen Time, which the simulator cannot grant.
final class SeuilUITests: XCTestCase {
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(onboarded: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [onboarded ? "--skip-onboarding" : "--reset-onboarding"]
        app.launch()
        return app
    }

    func testOnboardingWalksThroughEveryStep() {
        let app = launch(onboarded: false)
        let primary = app.buttons["onboarding.primary"]
        let heading = app.staticTexts["onboarding.heading"]

        XCTAssertTrue(heading.waitForExistence(timeout: timeout))
        XCTAssertTrue(heading.label.contains("Reprends la main"))
        primary.tap()

        XCTAssertTrue(heading.label.contains("appelles"))
        let nameField = app.textFields["onboarding.name"]
        nameField.tap()
        nameField.typeText("Adrien\n")
        primary.tap()

        XCTAssertTrue(heading.label.contains("Combien de temps"))
        XCTAssertTrue(app.staticTexts["4 h"].exists, "default is 4 hours a day")
        primary.tap()

        // 4 h a day for the 55 years left at 25: 9.2 years.
        XCTAssertTrue(heading.label.contains("9,2 ans"), heading.label)
        primary.tap()

        XCTAssertTrue(heading.label.contains("récupérer"))
        XCTAssertFalse(primary.isEnabled, "a goal is required")
        app.buttons["Mieux dormir"].tap()
        XCTAssertTrue(primary.isEnabled)
        primary.tap()

        XCTAssertTrue(heading.label.contains("essentielles"))
        primary.tap()
        XCTAssertTrue(heading.label.contains("besoin"))
        primary.tap()
        XCTAssertTrue(heading.label.contains("engager"))
        XCTAssertTrue(app.staticTexts["Disponible avec Seuil Pro"].exists, "Hard Mode is a Pro feature")
        primary.tap()

        XCTAssertTrue(heading.label.contains("mériter"))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Phrase à recopier")).firstMatch.tap()
        primary.tap()

        XCTAssertTrue(heading.label.contains("Adrien, voici les règles"), heading.label)
        XCTAssertTrue(app.buttons["Travail"].isSelected, "work routine is proposed by default")
        primary.tap()

        XCTAssertTrue(heading.label.contains("autorisations"))
        app.buttons["onboarding.later"].tap()
        XCTAssertTrue(app.buttons["Mes Apps"].waitForExistence(timeout: timeout))
    }

    func testMathChallengeCanBeSolved() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Jeux de maths", in: app)
        app.buttons["settings.tryChallenge"].tap()

        let first = app.staticTexts["math.problem.0"]
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        var index = 0
        while app.staticTexts["math.problem.\(index)"].exists {
            let problem = app.staticTexts["math.problem.\(index)"].label
            let field = app.textFields["math.answer.\(index)"]
            field.tap()
            field.typeText(String(Self.solve(problem)))
            index += 1
        }
        XCTAssertGreaterThan(index, 0)
        app.buttons["challenge.validate"].tap()
        XCTAssertTrue(app.staticTexts["settings.challengeResult"].waitForExistence(timeout: timeout))
    }

    func testWrongMathAnswerGivesNewProblems() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Jeux de maths", in: app)
        app.buttons["settings.tryChallenge"].tap()

        let first = app.staticTexts["math.problem.0"]
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        var index = 0
        while app.staticTexts["math.problem.\(index)"].exists {
            let field = app.textFields["math.answer.\(index)"]
            field.tap()
            field.typeText("-1")
            index += 1
        }
        app.buttons["challenge.validate"].tap()
        XCTAssertTrue(app.staticTexts["Au moins une réponse est fausse. Voici de nouveaux calculs."].waitForExistence(timeout: timeout))
        XCTAssertFalse(app.staticTexts["settings.challengeResult"].exists)
    }

    func testTypingChallengeCanBeSolved() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Phrase à recopier", in: app)
        app.buttons["settings.tryChallenge"].tap()

        let phrase = app.staticTexts["typing.phrase"]
        XCTAssertTrue(phrase.waitForExistence(timeout: timeout))
        let text = phrase.label.trimmingCharacters(in: CharacterSet(charactersIn: "«» "))
        let input = app.textFields["typing.input"]
        input.tap()
        input.typeText(text)
        app.buttons["Valider"].tap()
        XCTAssertTrue(app.staticTexts["settings.challengeResult"].waitForExistence(timeout: timeout))
        selectChallenge("Jeux de maths", in: app)
    }

    func testRoutineTemplateNeedsAppsBeforeSaving() {
        let app = launch(onboarded: true)
        app.buttons["Mes Apps"].tap()
        app.buttons["apps.newRule"].tap()
        let add = app.buttons["Ajouter Sommeil profond"]
        XCTAssertTrue(add.waitForExistence(timeout: timeout))
        add.tap()

        let save = app.buttons["Enregistrer"]
        XCTAssertTrue(save.waitForExistence(timeout: timeout))
        XCTAssertFalse(save.isEnabled, "a routine without apps cannot be saved")
        XCTAssertTrue(app.staticTexts["Se termine le lendemain matin."].exists)
        XCTAssertTrue(app.switches["Mode strict"].exists)
        // Tapping a Form row's centre misses the control; tap the switch itself.
        app.switches["Bloquer toutes les apps"].switches.firstMatch.tap()
        XCTAssertTrue(save.isEnabled, "blocking everything needs no app list")
        app.buttons["Annuler"].tap()
        XCTAssertFalse(save.waitForExistence(timeout: 2))
    }

    func testTimerAdjustsDurationAndAsksToCommit() {
        let app = launch(onboarded: true)
        app.buttons["Minuteur"].tap()
        XCTAssertTrue(app.otherElements["Minuteur 30:00"].waitForExistence(timeout: timeout))
        app.buttons["Plus"].tap()
        XCTAssertTrue(app.otherElements["Minuteur 35:00"].waitForExistence(timeout: timeout))
        app.buttons["Moins"].tap()
        app.buttons["Moins"].tap()
        XCTAssertTrue(app.otherElements["Minuteur 25:00"].waitForExistence(timeout: timeout))
        app.buttons["timer.start"].tap()
        XCTAssertTrue(app.buttons["commit.hold"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.switches["Mode strict"].exists)
    }

    func testPauseChallengeUnlocksAfterCountdown() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Exercices de respiration", in: app)
        app.buttons["Facile"].tap()
        app.buttons["settings.tryChallenge"].tap()

        let proceed = app.buttons["Continuer"]
        XCTAssertTrue(proceed.waitForExistence(timeout: timeout))
        XCTAssertFalse(proceed.isEnabled, "locked during the pause")
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: proceed)
        wait(for: [enabled], timeout: 20)
        proceed.tap()
        XCTAssertTrue(app.staticTexts["settings.challengeResult"].waitForExistence(timeout: timeout))
        app.buttons["Moyen"].tap()
        selectChallenge("Jeux de maths", in: app)
    }

    func testReasonChallengeAcceptsConcreteAndRefusesScrolling() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Motif valable", in: app)
        app.buttons["settings.tryChallenge"].tap()

        let editor = app.textViews["Ton motif"]
        XCTAssertTrue(editor.waitForExistence(timeout: timeout))
        editor.tap()
        editor.typeText("Je m'ennuie, je veux juste scroller")
        app.buttons["Valider mon motif"].tap()
        XCTAssertTrue(app.staticTexts["Ça ressemble à du défilement sans objectif. Refusé."].waitForExistence(timeout: 30))

        editor.tap()
        editor.press(forDuration: 1.2)
        if app.menuItems["Tout sélectionner"].waitForExistence(timeout: 2) { app.menuItems["Tout sélectionner"].tap() }
        else if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        editor.typeText(XCUIKeyboardKey.delete.rawValue)
        editor.typeText("Répondre au message de Léa pour samedi soir")
        app.buttons["Valider mon motif"].tap()
        XCTAssertTrue(app.staticTexts["settings.challengeResult"].waitForExistence(timeout: 30))
        selectChallenge("Jeux de maths", in: app)
    }

    func testPuzzleChallengeInOrder() {
        let app = launch(onboarded: true)
        openSettings(app)
        selectChallenge("Jeux de puzzle", in: app)
        app.buttons["Facile"].tap()
        app.buttons["settings.tryChallenge"].tap()
        let first = app.buttons["puzzle.1"]
        XCTAssertTrue(first.waitForExistence(timeout: timeout))
        for value in 1...9 { app.buttons["puzzle.\(value)"].tap() }
        XCTAssertTrue(app.staticTexts["settings.challengeResult"].waitForExistence(timeout: timeout))
        app.buttons["Moyen"].tap()
        selectChallenge("Jeux de maths", in: app)
    }

    /// Profile menu › Paramètres › Salle d’attente, where challenges are chosen.
    private func openSettings(_ app: XCUIApplication) {
        let profile = app.buttons["home.settings"]
        XCTAssertTrue(profile.waitForExistence(timeout: timeout))
        profile.tap()
        let settings = app.buttons["menu.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        settings.tap()
        let waitingRoom = app.buttons["settings.waitingRoom"]
        XCTAssertTrue(waitingRoom.waitForExistence(timeout: timeout))
        waitingRoom.tap()
        XCTAssertTrue(app.buttons["settings.tryChallenge"].waitForExistence(timeout: timeout))
    }

    private static let challengeTitles = ["Exercices de respiration", "Jeux de maths", "Jeux de puzzle", "Phrase à recopier", "Motif valable"]

    /// Leaves exactly one challenge enabled so "Essayer le défi" is deterministic.
    private func selectChallenge(_ title: String, in app: XCUIApplication) {
        let wanted = app.switches[title]
        XCTAssertTrue(wanted.waitForExistence(timeout: timeout), title)
        if (wanted.value as? String) != "1" { tapSwitch(wanted, in: app) }
        for other in Self.challengeTitles where other != title {
            let toggle = app.switches[other]
            if toggle.exists, (toggle.value as? String) == "1" { tapSwitch(toggle, in: app) }
        }
    }

    private func tapSwitch(_ toggle: XCUIElement, in app: XCUIApplication) {
        if !toggle.isHittable { app.swipeUp() }
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
    }

    /// Solves "a + b", "a × b" and "a × b − c" as shown by the math challenge.
    static func solve(_ problem: String) -> Int {
        let text = problem.replacingOccurrences(of: "=", with: "")
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        if text.contains("+") { return numbers[0] + numbers[1] }
        if text.contains("−") { return numbers[0] * numbers[1] - numbers[2] }
        return numbers[0] * numbers[1]
    }
}
