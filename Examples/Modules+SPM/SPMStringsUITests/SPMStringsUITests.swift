//
//  SPMStringsUITests.swift
//  SPMStringsUITests
//
//  Created by Sergey Balalaev on 21.03.2024.
//

import XCTest

final class SPMStringsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCommon() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        app.staticTexts["Help me"].waitForExistingAndAssert(timeout: 5)
        app.staticTexts["We support new localisation format"].waitForExistingAndAssert(timeout: 5)
    }
}
