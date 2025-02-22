//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceOTel

extension Embrace: EmbraceOpenTelemetry {

    private var otel: EmbraceOTel { EmbraceOTel() }

    /// Returns an OpenTelemetry SpanBuilder that is using an Embrace Tracer
    /// - Parameters:
    ///     - name: The name of the span
    ///     - type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    /// - Returns: An OpenTelemetry SpanBuilder
    public func buildSpan(
        name: String,
        type: SpanType = .performance,
        attributes: [String: String] = [:]
    ) -> SpanBuilder {
        otel.buildSpan(name: name, type: type, attributes: attributes)
    }

    /// Record a span after the fact
    /// - Parameters
    ///     - name: The name of the span
    ///     - type: The Embrace SpanType to mark this span. Defaults to `performance`
    ///     - parent: The parent span, if this span is a child
    ///     - startTime: The start time of the span
    ///     - endTime: The end time of the span
    ///     - attributes: A dictionary of attributes to set on the span. Defaults to an empty dictionary
    ///     - events: An array of events to add to the span. Defaults to an empty array
    ///     - errorCode: The error code of the span. Defaults to `noError`
    public func recordCompletedSpan(
        name: String,
        type: SpanType = .performance,
        parent: Span? = nil,
        startTime: Date,
        endTime: Date,
        attributes: [String: String] = [:],
        events: [RecordingSpanEvent] = [],
        errorCode: ErrorCode? = nil
    ) {
        let builder = otel
            .buildSpan(name: name, type: type, attributes: attributes)
            .setStartTime(time: startTime)
        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        events.forEach { event in
            span.addEvent(name: event.name, attributes: event.attributes, timestamp: event.timestamp)
        }

        span.end(time: endTime)
    }

    /// Adds a list of SpanEvent objects to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter events: An array of SpanEvent objects
    public func add(events: [SpanEvent]) {
        sessionController.currentSessionSpan?.add(events: events)
    }

    /// Adds a single SpanEvent object to the current session span
    /// If there is no current session, this event will be dropped
    /// - Parameter event: A SpanEvent object
    public func add(event: SpanEvent) {
        add(events: [event])
    }
}

extension Embrace { // MARK: Static methods

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters
    ///     - name: The name of the span
    ///     -  parent: The parent span, if this span is a child
    ///     -  type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    ///     - block: The block to execute, receives an an optional Span as an argument to allow block to append events or properties
    /// - Returns  The result of the block
    ///
    /// - Note This method validates the presence of the Embrace client and will call the block with a nil span if the client is not present
    ///                 It is recommended you use this method in order to be sure the block is run correctly.
    public static func recordSpan<T>(
        name: String,
        parent: Span? = nil,
        type: SpanType = .performance,
        attributes: [String: String] = [:],
        block: (Span?) throws -> T
    ) rethrows -> T {
        guard let embrace = Embrace.client else {
            // DEV: be sure to execute block if Embrace client is nil
            return try block(nil)
        }

        return try embrace.recordSpan(
            name: name,
            parent: parent,
            type: type,
            attributes: attributes,
            block: block
        )
    }
}

extension Embrace { // MARK: Internal methods

    /// Starts a span and executes the block. The span will be ended when the block returns
    /// - Parameters
    ///     - name: The name of the span
    ///     -  parent: The parent span, if this span is a child
    ///     -  type: The type of the span. Will be set as the `emb.type` attribute
    ///     - attributes: A dictionary of attributes to set on the span
    ///     - block: The block to execute, receives an an optional Span as an argument to allow block to append events or properties
    /// - Returns  The result of the block
    ///
    ///
    /// **Note** This method is not exposed publicly to prevent optional chaining from preventing the block from running.
    /// It is recommended to use the static ``Embrace.recordSpan`` method.
    /// ```swift
    /// Embrace.client?.recordSpan(name: "example", type: .performance) {
    ///    // If Embrace.client is nil, this block will not execute
    ///    // Use `Embrace.recordSpan` to ensure the block is executed
    /// }
    /// ```
    func recordSpan<T>(
        name: String,
        parent: Span? = nil,
        type: SpanType,
        attributes: [String: String] = [:],
        block: (Span) throws -> T
    ) rethrows -> T {
        let builder = otel.buildSpan(name: name, type: type, attributes: attributes)
        if let parent = parent { builder.setParent(parent) }
        let span = builder.startSpan()

        let result = try block(span)

        span.end()
        return result
    }
}
