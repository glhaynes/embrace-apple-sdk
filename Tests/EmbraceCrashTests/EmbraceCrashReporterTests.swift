//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceCrash

class EmbraceCrashReporterTests: XCTestCase {

    var context: CollectorContext = .testContext

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: context.filePathProvider.directoryURL(for: "")!)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: context.filePathProvider.directoryURL(for: "")!)
    }

    func test_currentSessionId() {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.install(context: context)

        // when setting the current session id
        let sessionId = SessionIdentifier.random
        crashReporter.currentSessionId = sessionId

        // then KSCrash's user info is properly set
        let key = EmbraceCrashReporter.UserInfoKey.sessionId
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, sessionId.toString)
    }

    func test_sdkVersion() {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()

        // sdkversion set via context
        crashReporter.install(context: context)

        // then KSCrash's user info is properly set
        let key = EmbraceCrashReporter.UserInfoKey.sdkVersion
        XCTAssertEqual(crashReporter.ksCrash?.userInfo[key] as? String, TestConstants.sdkVersion)
    }

    func test_fetchCrashReports() throws {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.install(context: context)
        crashReporter.start()

        // given some fake crash report
        try FileManager.default.createDirectory(atPath: crashReporter.basePath! + "/Reports", withIntermediateDirectories: true)
        let report = Bundle.module.path(forResource: "crash_report", ofType: "json", inDirectory: "Mocks")!
        let finalPath = crashReporter.basePath! + "/Reports/appId-report-0000000000000001.json"
        try FileManager.default.copyItem(atPath: report, toPath: finalPath)

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 1)
            XCTAssertEqual(reports[0].sessionId, TestConstants.sessionId)
            XCTAssertNotNil(reports[0].timestamp)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchCrashReports_count() throws {
        // given a crash reporter
        let crashReporter = EmbraceCrashReporter()
        crashReporter.install(context: context)
        crashReporter.start()

        // given some fake crash report
        try FileManager.default.createDirectory(atPath: crashReporter.basePath! + "/Reports", withIntermediateDirectories: true)
        let report = Bundle.module.path(forResource: "crash_report", ofType: "json", inDirectory: "Mocks")!

        for i in 1...9 {
            let finalPath = crashReporter.basePath! + "/Reports/appId-report-000000000000000\(i).json"
            try FileManager.default.copyItem(atPath: report, toPath: finalPath)
        }

        // then the report is fetched
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 9)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }
}
