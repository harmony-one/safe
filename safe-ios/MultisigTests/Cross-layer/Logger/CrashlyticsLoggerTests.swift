//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import Multisig

class CrashlyticsLoggerTests: XCTestCase {

    var logger: CrashlyticsLogger!
    let mockCrashlytics = MockCrashlytics()
    let testMessage = "Test Error"

    override func setUp() {
        super.setUp()
        logger = CrashlyticsLogger(crashlytics: mockCrashlytics)
    }

    func test_whenLoggingWithoutError_thenNothingHappens() {
        logger.log(testMessage, level: .error, error: nil, file: "", line: 0, function: "")
        XCTAssertNil(mockCrashlytics.loggedError)
    }

    func test_whenLoggingWithError_thenLogged() {
        logger.log(testMessage, level: .error, error: TestLoggableError.error, file: "", line: 0, function: "")
        XCTAssertEqual(mockCrashlytics.loggedError?.localizedDescription, TestLoggableError.error.localizedDescription)
    }

    func test_whenLoggingWithError_thenUserInfoHasMessage() {
        logger.log(testMessage, level: .error, error: TestLoggableError.error, file: "", line: 0, function: "")
        XCTAssertEqual((mockCrashlytics.loggedError as NSError?)?.userInfo["message"] as? String, testMessage)
    }

    func test_whenLoggingLoggableError_thenUserInfoHasLoggableKeys() {
        logger.log(testMessage, level: .error, error: TestLoggableError.error, file: "", line: 0, function: "")
        XCTAssertEqual((mockCrashlytics.loggedError as NSError?)?.userInfo[LoggableErrorDescriptionKey] as? String,
                       "error")
    }

}

class MockCrashlytics: CrashlyticsProtocol {
    var loggedError: Error?

    func record(error: Error) {
        loggedError = error
    }

    func setUserID(_ identifier: String) {
        // empty
    }

    func log(format: String, arguments: CVaListPointer) {
        // empty
    }

    func setCrashlyticsCollectionEnabled(_ enabled: Bool) {
        // empty
    }
}
