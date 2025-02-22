//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceCore
import EmbraceStorage
import EmbraceCommon
import TestSupport

final class SessionPayloadBuilderTests: XCTestCase {

    var storage: EmbraceStorage!
    var sessionRecord: SessionRecord!

    override func setUpWithError() throws {
        storage = try EmbraceStorage.createInDiskDb()

        sessionRecord = SessionRecord(
            id: TestConstants.sessionId,
            state: .foreground,
            processId: ProcessIdentifier.current,
            traceId: TestConstants.traceId,
            spanId: TestConstants.spanId,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 60)
        )
    }

    override func tearDownWithError() throws {
        try storage.dbQueue.write { db in
            try SessionRecord.deleteAll(db)
            try ResourceRecord.deleteAll(db)
        }

        sessionRecord = nil
        try storage.teardown()
    }

    func test_counterMissing() throws {
        // given no existing counter in storage
        var resource = try storage.fetchPermanentResource(key: SessionPayloadBuilder.resourceName)
        XCTAssertNil(resource)

        // when building a session payload
        let payload = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then a resource is created with the correct value
        resource = try storage.fetchPermanentResource(key: SessionPayloadBuilder.resourceName)
        XCTAssertEqual(resource!.value, .string("1"))
        XCTAssertEqual(payload.sessionInfo.counter, 1)
    }

    func test_existingCounter() throws {
        // given existing counter in storage
        try storage.addResource(key: SessionPayloadBuilder.resourceName, value: "10", resourceType: .permanent)
        var resource = try storage.fetchPermanentResource(key: SessionPayloadBuilder.resourceName)
        XCTAssertNotNil(resource)

        // when building a session payload
        let payload = SessionPayloadBuilder.build(for: sessionRecord, storage: storage)

        // then the counter is updated correctly
        resource = try storage.fetchPermanentResource(key: SessionPayloadBuilder.resourceName)
        XCTAssertEqual(resource!.value, .string("11"))
        XCTAssertEqual(payload.sessionInfo.counter, 11)
    }
}
