//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import XCTest
@testable import EmbraceCore
import EmbraceCommon
import EmbraceStorage
@testable import EmbraceUpload
import TestSupport
import GRDB

class UnsentDataHandlerTests: XCTestCase {
    let filePathProvider = TemporaryFilepathProvider()
    var context: CaptureServiceContext!

    static let testSessionsUrl = URL(string: "https://embrace.test.com/sessions")!
    static let testBlobsUrl = URL(string: "https://embrace.test.com/blobs")!

    static let testEndpointOptions = EmbraceUpload.EndpointOptions(
        sessionsURL: UnsentDataHandlerTests.testSessionsUrl,
        blobsURL: UnsentDataHandlerTests.testBlobsUrl
    )
    static let testCacheOptions = EmbraceUpload.CacheOptions(
        cacheBaseUrl: URL(fileURLWithPath: NSTemporaryDirectory())
    )!
    static let testMetadataOptions = EmbraceUpload.MetadataOptions(
        apiKey: "apiKey",
        userAgent: "userAgent",
        deviceId: "12345678"
    )
    static let testRedundancyOptions = EmbraceUpload.RedundancyOptions(automaticRetryCount: 0)

    var uploadOptions: EmbraceUpload.Options!
    var queue: DispatchQueue!

    override func setUpWithError() throws {
        // delete tmpdir
        try? FileManager.default.removeItem(at: filePathProvider.tmpDirectory)

        context = CaptureServiceContext(
            appId: TestConstants.appId,
            sdkVersion: TestConstants.sdkVersion,
            filePathProvider: filePathProvider )

        // create upload options
        let urlSessionconfig = URLSessionConfiguration.ephemeral
        urlSessionconfig.protocolClasses = [EmbraceHTTPMock.self]

        uploadOptions = EmbraceUpload.Options(
            endpoints: UnsentDataHandlerTests.testEndpointOptions,
            cache: UnsentDataHandlerTests.testCacheOptions,
            metadata: UnsentDataHandlerTests.testMetadataOptions,
            redundancy: UnsentDataHandlerTests.testRedundancyOptions,
            urlSessionConfiguration: urlSessionconfig
        )

        EmbraceHTTPMock.setUp()

        self.queue = DispatchQueue(label: "com.test.embrace.queue", attributes: .concurrent)
    }

    override func tearDownWithError() throws {
        // delete tmpdir
        try? FileManager.default.removeItem(at: filePathProvider.tmpDirectory)
    }

    func test_withoutCrashReporter() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: Self.testSessionsUrl)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInDiskDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, queue: queue)

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, crashReporter: nil)
        wait(delay: .longTimeout)

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(UnsentDataHandlerTests.testSessionsUrl).count, 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)
    }

    func test_withoutCrashReporter_error() throws {
        // mock error requests
        EmbraceHTTPMock.mock(url: UnsentDataHandlerTests.testSessionsUrl, errorCode: 500)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInDiskDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, queue: queue)

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, crashReporter: nil)
        wait(delay: .longTimeout)

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(UnsentDataHandlerTests.testSessionsUrl).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 1)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session upload data cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 1)
    }

    func test_withCrashReporter() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: Self.testSessionsUrl)
        EmbraceHTTPMock.mock(url: Self.testBlobsUrl)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInDiskDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, queue: queue)

        // given a crash reporter
        let crashReporter = CrashReporterMock()

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, crashReporter: crashReporter)

        // then the crash report id is set on the session
        let expectation1 = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil {
                    expectation1.fulfill()
                }
            }
        }
        wait(delay: .longTimeout)

        // then a crash report was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(Self.testBlobsUrl).count, 1)

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(Self.testSessionsUrl).count, 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the crash is not longer stored
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // clean up
        cancellable.cancel()
    }

    func test_withCrashReporter_error() throws {
        // mock error requests
        EmbraceHTTPMock.mock(url: Self.testSessionsUrl, errorCode: 500)
        EmbraceHTTPMock.mock(url: Self.testBlobsUrl, errorCode: 500)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInDiskDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, queue: queue)

        // given a crash reporter
        let crashReporter = CrashReporterMock()

        // given a finished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60),
            endTime: Date()
        )

        // when failing to send unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, crashReporter: crashReporter)

        // then the crash report id is set on the session
        let expectation1 = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll)
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil {
                    expectation1.fulfill()
                }
            }
        }
        wait(delay: .longTimeout)

        // then a crash report request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(Self.testBlobsUrl).count, 0)

        // then a session request was attempted
        XCTAssertGreaterThan(EmbraceHTTPMock.requestsForUrl(Self.testSessionsUrl).count, 0)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data are still cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 2)

        // then the crash is not longer stored
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // clean up
        cancellable.cancel()
    }

    func test_withCrashReporter_unfinishedSession() throws {
        // mock successful requests
        EmbraceHTTPMock.mock(url: Self.testSessionsUrl)
        EmbraceHTTPMock.mock(url: Self.testBlobsUrl)

        // given a storage and upload modules
        let storage = try EmbraceStorage.createInDiskDb()
        defer { try? storage.teardown() }

        let upload = try EmbraceUpload(options: uploadOptions, queue: queue)

        // given a crash reporter
        let crashReporter = CrashReporterMock()

        // given an unfinished session in the storage
        try storage.addSession(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSinceNow: -60)
        )

        // when sending unsent sessions
        UnsentDataHandler.sendUnsentData(storage: storage, upload: upload, crashReporter: crashReporter)

        // then the crash report id and timestamp is set on the session
        let expectation1 = XCTestExpectation()
        let observation = ValueObservation.tracking(SessionRecord.fetchAll).print()
        let cancellable = observation.start(in: storage.dbQueue) { error in
            XCTAssert(false, error.localizedDescription)
        } onChange: { records in
            if let record = records.first {
                if record.crashReportId != nil && record.endTime != nil {
                    expectation1.fulfill()
                }
            }
        }
        wait(delay: .longTimeout)

        // then a crash report was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(Self.testBlobsUrl).count, 1)

        // then a session request was sent
        XCTAssertEqual(EmbraceHTTPMock.requestsForUrl(Self.testSessionsUrl).count, 1)

        // then the total amount of requests is correct
        XCTAssertEqual(EmbraceHTTPMock.totalRequestCount(), 2)

        // then the session is no longer on storage
        let session = try storage.fetchSession(id: TestConstants.sessionId)
        XCTAssertNil(session)

        // then the session and crash report upload data is no longer cached
        let uploadData = try upload.cache.fetchAllUploadData()
        XCTAssertEqual(uploadData.count, 0)

        // then the crash is not longer stored
        let expectation = XCTestExpectation()
        crashReporter.fetchUnsentCrashReports { reports in
            XCTAssertEqual(reports.count, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: .defaultTimeout)

        // clean up
        cancellable.cancel()
    }
}
