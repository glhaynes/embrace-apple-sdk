//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import XCTest
@testable import EmbraceOTel
import OpenTelemetryApi

final class RecordingSpanTests: XCTestCase {

    func test_isRecording_trueIfEndTime_isNil() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        XCTAssertNil(span.endTime)
        XCTAssertTrue(span.isRecording)

        span.end(time: Date())
        XCTAssertFalse(span.isRecording)
    }

    func test_setAttribute_setsAttribute() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.setAttribute(key: "foo", value: "bar")
        XCTAssertEqual(span.attributes, ["foo": .string("bar")])
    }

    func test_addEvent_withName_addsToEventsArray() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.addEvent(name: "example")
        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events.first?.name, "example")
    }

    func test_addEvent_withNameAndTimestamp_addsToEventsArray() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let eventTime = Date().addingTimeInterval(-20)

        span.addEvent(name: "example", timestamp: eventTime)

        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events.first?.name, "example")
        XCTAssertEqual(span.events.first?.timestamp, eventTime)
    }

    func test_addEvent_withNameAndAttributes_addsToEventsArray() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)

        span.addEvent(name: "example", attributes: ["foo": .string("bar")])

        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events.first?.name, "example")
        XCTAssertEqual(span.events.first?.attributes, ["foo": .string("bar")])
    }

    func test_addEvent_withNameTimestampAndAttributes_addsToEventsArray() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let eventTime = Date().addingTimeInterval(-20)

        span.addEvent(name: "example", attributes: ["foo": .string("bar")], timestamp: eventTime)

        XCTAssertEqual(span.events.count, 1)
        XCTAssertEqual(span.events.first?.name, "example")
        XCTAssertEqual(span.events.first?.timestamp, eventTime)
        XCTAssertEqual(span.events.first?.attributes, ["foo": .string("bar")])
    }

    func test_addEvent_multipleTimes_addsToEventsArray() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let eventTime = Date().addingTimeInterval(-20)

        let eventToTimeMap = [
            "example-0": eventTime,
            "example-1": eventTime.addingTimeInterval(4),
            "example-2": eventTime.addingTimeInterval(8)
        ]

        eventToTimeMap.forEach { name, timestamp in
            span.addEvent(name: name, timestamp: timestamp)
        }

        XCTAssertEqual(span.events.count, 3)
        XCTAssertEqual(span.events.map { $0.name}, Array(eventToTimeMap.keys))
        XCTAssertEqual(span.events.map { $0.timestamp}, Array(eventToTimeMap.values))
    }

    func test_end_setsEndTime_toCurrentTime() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let before = Date()
        Thread.sleep(forTimeInterval: 0.001) // DEV: explicit sleep for precision comparison in "assert greater than"

        XCTAssertNil(span.endTime)
        span.end()
        XCTAssertNotNil(span.endTime)
        XCTAssertGreaterThan(span.endTime!, before)
    }

    func test_end_withTime_setsEndTime_toPassedTime() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let endTime = Date().addingTimeInterval(-10)

        span.end(time: endTime)
        XCTAssertEqual(span.endTime, endTime)
    }

    func test_end_setsStatus_toOk_ifUnset() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        XCTAssertEqual(span.status, .unset)

        span.end()
        XCTAssertEqual(span.status, .ok)
    }

    func test_end_doesNot_setStatus_toOk_ifError() throws {
        let errorStatus = Status.error(description: "unable to example")

        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.status = errorStatus
        XCTAssertEqual(span.status, errorStatus)

        span.end()
        XCTAssertEqual(span.status, errorStatus)
    }

    func test_description_containsDescriptiveMessage() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        let description = span.description

        XCTAssertTrue(description.contains("RecordingSpan"))
        XCTAssertTrue(description.contains("'example'"))
    }

    func test_end_errorCode() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.end(errorCode: .failure)

        let value = AttributeValue.string(SpanErrorCode.failure.rawValue)
        XCTAssertEqual(span.attributes[SpanAttributeKey.errorCode.rawValue], value)
        XCTAssertNotNil(span.endTime)
    }

    func test_end_error() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.end(error: NSError(domain: "com.embrace.test", code: 123))

        XCTAssertNotNil(span.attributes[SpanErrorAttributeKey.message.rawValue])
        let value1 = AttributeValue.int(123)
        XCTAssertEqual(span.attributes[SpanErrorAttributeKey.code.rawValue], value1)

        let value2 = AttributeValue.string(SpanErrorCode.failure.rawValue)
        XCTAssertEqual(span.attributes[SpanAttributeKey.errorCode.rawValue], value2)

        XCTAssertNotNil(span.endTime)
    }

    func test_end_error_and_errorCode() throws {
        let span = RecordingSpan(startTime: Date(), context: .create(), name: "example", processor: .noop)
        span.end(error: NSError(domain: "com.embrace.test", code: 123), errorCode: .userAbandon)

        XCTAssertNotNil(span.attributes[SpanErrorAttributeKey.message.rawValue])
        let value1 = AttributeValue.int(123)
        XCTAssertEqual(span.attributes[SpanErrorAttributeKey.code.rawValue], value1)

        let value2 = AttributeValue.string(SpanErrorCode.userAbandon.rawValue)
        XCTAssertEqual(span.attributes[SpanAttributeKey.errorCode.rawValue], value2)

        XCTAssertNotNil(span.endTime)
    }
}
