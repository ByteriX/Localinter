//
//  XCUIElement.swift
//  SPMStringsUITests
//
//  Created by Sergey Balalaev on 21.03.2024.
//

import Foundation
import XCTest

extension XCUIElement {
    @discardableResult
    func waitForExistence() -> Bool {
        waitForExistence(timeout: 0)
    }

    func waitForExistingAndAssert(timeout: TimeInterval = 0) {
        XCTAssert(waitForExistence(timeout: timeout), "Not found element with \(self.label)")
    }
}
