//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
import TestSupport
import EmbraceCommon
@testable import EmbraceStorage

// swiftlint:disable cyclomatic_complexity

class SessionRecordTests: XCTestCase {
    var storage: EmbraceStorage!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInDiskDb()
    }

    override func tearDownWithError() throws {
        try storage.teardown()
    }

    func test_tableSchema() throws {
        let expectation = XCTestExpectation()

        // then the table and its colums should be correct
        try storage.dbQueue.read { db in
            XCTAssert(try db.tableExists(SessionRecord.databaseTableName))

            let columns = try db.columns(in: SessionRecord.databaseTableName)
            XCTAssertEqual(columns.count, 12, "Column count does not match expectation. Did you add/remove a column?")

            // id
            let idColumn = columns.first(where: { $0.name == "id" })
            if let idColumn = idColumn {
                XCTAssertEqual(idColumn.type, "TEXT")
                XCTAssert(idColumn.isNotNull)
                XCTAssert(try db.table(SessionRecord.databaseTableName, hasUniqueKey: ["id"]))
            } else {
                XCTAssert(false, "id column not found!")
            }

            // state
            let stateTimeColumn = columns.first(where: { $0.name == "state" })
            if let stateTimeColumn = stateTimeColumn {
                XCTAssertEqual(stateTimeColumn.type, "TEXT")
                XCTAssert(stateTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "state column not found!")
            }

            // process_id
            let processIdColumn = columns.first(where: { $0.name == "process_id" })
            if let processIdColumn = processIdColumn {
                XCTAssertEqual(processIdColumn.type, "TEXT")
                XCTAssert(processIdColumn.isNotNull)
            } else {
                XCTAssert(false, "process_id column not found!")
            }

            // trace_id
            let traceIdColumn = columns.first(where: { $0.name == "trace_id" })
            if let traceIdColumn = traceIdColumn {
                XCTAssertEqual(traceIdColumn.type, "TEXT")
                XCTAssert(traceIdColumn.isNotNull)
            } else {
                XCTAssert(false, "trace_id column not found!")
            }

            // span_id
            let spanIdColumn = columns.first(where: { $0.name == "span_id" })
            if let spanIdColumn = spanIdColumn {
                XCTAssertEqual(spanIdColumn.type, "TEXT")
                XCTAssert(spanIdColumn.isNotNull)
            } else {
                XCTAssert(false, "span_id column not found!")
            }

            // start_time
            let startTimeColumn = columns.first(where: { $0.name == "start_time" })
            if let startTimeColumn = startTimeColumn {
                XCTAssertEqual(startTimeColumn.type, "DATETIME")
                XCTAssert(startTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "start_time column not found!")
            }

            // end_time
            let endTimeColumn = columns.first(where: { $0.name == "end_time" })
            if let endTimeColumn = endTimeColumn {
                XCTAssertEqual(endTimeColumn.type, "DATETIME")
            } else {
                XCTAssert(false, "end_time column not found!")
            }

            // last_heartbeat_time
            let lastHeartbeatTimeColumn = columns.first(where: { $0.name == "last_heartbeat_time" })
            if let lastHeartbeatTimeColumn = lastHeartbeatTimeColumn {
                XCTAssertEqual(lastHeartbeatTimeColumn.type, "DATETIME")
                XCTAssert(lastHeartbeatTimeColumn.isNotNull)
            } else {
                XCTAssert(false, "last_heartbeat_time column not found!")
            }

            // crash_report_id
            let crashReportIdColumn = columns.first(where: { $0.name == "crash_report_id" })
            if let crashReportIdColumn = crashReportIdColumn {
                XCTAssertEqual(crashReportIdColumn.type, "TEXT")
            } else {
                XCTAssert(false, "crash_report_id column not found!")
            }

            // cold_start
            let coldStartColumn = columns.first(where: { $0.name == "cold_start" })
            if let coldStartColumn = coldStartColumn {
                XCTAssertEqual(coldStartColumn.type, "BOOLEAN")
                XCTAssertTrue(coldStartColumn.isNotNull)
                XCTAssertEqual(coldStartColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "cold_start column not found!")
            }

            // clean_exit
            let cleanExitColumn = columns.first(where: { $0.name == "clean_exit" })
            if let cleanExitColumn = cleanExitColumn {
                XCTAssertEqual(cleanExitColumn.type, "BOOLEAN")
                XCTAssertTrue(cleanExitColumn.isNotNull)
                XCTAssertEqual(cleanExitColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "clean_exit column not found!")
            }

            // app_terminated
            let appTerminatedColumn = columns.first(where: { $0.name == "app_terminated" })
            if let appTerminatedColumn = appTerminatedColumn {
                XCTAssertEqual(appTerminatedColumn.type, "BOOLEAN")
                XCTAssertTrue(appTerminatedColumn.isNotNull)
                XCTAssertEqual(appTerminatedColumn.defaultValueSQL, "0")
            } else {
                XCTAssert(false, "app_terminated column not found!")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_addSession() throws {
        // given inserted session
        let session = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        XCTAssertNotNil(session)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try session.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_upsertSession() throws {
        // given inserted session
        let session = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        try storage.upsertSession(session)

        // then session should exist in storage
        let expectation = XCTestExpectation()
        try storage.dbQueue.read { db in
            XCTAssert(try session.exists(db))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)
    }

    func test_fetchSession() throws {
        // given inserted session
        let sessionId = SessionIdentifier.random
        let original = try storage.addSession(
            id: sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )

        // when fetching the session
        let session = try storage.fetchSession(id: sessionId)

        // then the session should be valid
        XCTAssertNotNil(session)
        XCTAssertEqual(original, session)
    }

    func test_fetchLatestSesssion() throws {
        // given inserted sessions
        _ = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        _ = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 10)
        )
        let session3 = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 20)
        )

        // when fetching the latest session
        let session = try storage.fetchLatestSesssion()

        // then the fetched session is valid
        XCTAssertEqual(session, session3)
    }

    func test_fetchOldestSesssion() throws {
        // given inserted sessions
        let session1 = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date()
        )
        _ = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 10)
        )
        _ = try storage.addSession(
            id: .random,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: 20)
        )

        // when fetching the oldest session
        let session = try storage.fetchOldestSesssion()

        // then the fetched session is valid
        XCTAssertEqual(session, session1)
    }
}

// swiftlint:enable cyclomatic_complexity
