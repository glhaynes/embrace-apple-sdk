import Foundation
import EmbraceCommon
import OpenTelemetryApi

// Android implementation
// https://github.com/embrace-io/embrace-android-sdk3/blob/561fd6b24de0e889f08d154478be132302daa0d0/embrace-android-sdk/src/main/java/io/embrace/android/embracesdk/internal/spans/SpansServiceImpl.kt
@objc public final class EmbraceOTel: NSObject {

    let instrumentationName = "EmbraceTracer"
    let instrumentationVersion = "semver:0.0.1"

    /// Setup the OpenTelemetryApi
    /// - Parameter: spanProcessor The processor in which to run during the lifetime of each Span
    public static func setup(spanProcessor: EmbraceSpanProcessor) {
        OpenTelemetry.registerTracerProvider(
            tracerProvider: EmbraceTracerProvider(spanProcessor: spanProcessor) )
    }

    public static func setup(logSharedState: EmbraceLogSharedState) {
        OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultEmbraceLoggerProvider(sharedState: logSharedState))
    }

    internal var logger: Logger {
        OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: instrumentationName)
    }

    // tracer
    internal var tracer: Tracer {
        OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: instrumentationName,
            instrumentationVersion: instrumentationVersion)
    }

    // methods to add span

    public func recordSpan<T>(
        name: String,
        type: SpanType,
        attributes: [String: String] = [:],
        spanOperation: () -> T
    ) -> T {
        let span = buildSpan(name: name, type: type, attributes: attributes)
                        .startSpan()
        let result = spanOperation()
        span.end()

        return result
    }

    public func buildSpan(
        name: String,
        type: SpanType,
        attributes: [String: String] = [:]
    ) -> SpanBuilder {

        let builder = tracer.spanBuilder(spanName: name)
                        .setAttribute(
                            key: SpanAttributeKey.type,
                            value: type.rawValue )

        for (key, value) in attributes {
            builder.setAttribute(key: key, value: value)
        }

        return builder
    }
}
