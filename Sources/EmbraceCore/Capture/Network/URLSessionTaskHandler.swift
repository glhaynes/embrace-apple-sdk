//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import OpenTelemetryApi
import EmbraceCommon
import EmbraceOTel

enum CaptureServiceHandlerState {
    case initialized
    case listening
    case paused
}

protocol CaptureServiceHandler {
    func changedState(to captureServiceState: CaptureServiceState)
}

protocol URLSessionTaskHandler: AnyObject, CaptureServiceHandler {
    func create(task: URLSessionTask)
    func finish(task: URLSessionTask, data: Data?, error: (any Error)?)
}

final class DefaultURLSessionTaskHandler: URLSessionTaskHandler {
    @ThreadSafe
    private(set) var state: CaptureServiceHandlerState
    private var spans: [URLSessionTask: Span] = [:]
    private let otel: EmbraceOpenTelemetry
    private let queue: DispatchQueue

    enum SpanAttribute {
        // Isn't address redundant?
        static let address = "server.address"
        static let url = "url.full"
        static let method = "http.request.method"
        static let bodySize = "http.request.body.size"
        static let statusCode = "http.response.status_code"
        static let responseSize = "http.response.body.size"
        static let errorType = "error.type"
        static let errorCode = "error.code"
        static let errorMessage = "error.message"
    }

    init(otel: EmbraceOpenTelemetry = EmbraceOTel(),
         initialState: CaptureServiceHandlerState = .initialized,
         processingQueue: DispatchQueue = DefaultURLSessionTaskHandler.queue()) {
        self.otel = otel
        self.state = initialState
        self.queue = processingQueue
    }

    func create(task: URLSessionTask) {
        queue.async {
            guard self.shouldTrack() else {
                return
            }

            guard let request = task.originalRequest, let url = request.url else {
                // TODO: Shall we log this as an error instead of only returning?
                return
            }

            // Probably this could be moved to a separate class
            var attributes: [String: String] = [:]
            attributes[SpanAttribute.url] = url.absoluteString

            let httpMethod = request.httpMethod ?? ""
            if !httpMethod.isEmpty {
                attributes[SpanAttribute.method] = httpMethod
            }

            // This should be modified if we start doing this for streaming tasks.
            if let bodySize = request.httpBody {
                attributes[SpanAttribute.bodySize] = String(bodySize.count)
            }

            /*
             Note: According to the OpenTelemetry specification, the attribute name should be ' {method} {http.route}.
             The `{http.route}` corresponds to the template of the path so it's necessary to understand the templating system being employed.
             For instance, a template for a request such as http://embrace.io/users/12345?hello=world
             would be reported as /users/:userId (or /users/:userId? in other templating system).

             Until a decision is made regarding the method to convey this information and the heuristics to extract it,
             the `.path` method will be utilized temporarily. This approach may introduce higher cardinality on the backend,
             which is less than optimal.
             It will be important to address this in the near future to enhance performance for the backend.

             Additional information can be found at:
             - HTTP Name attribute: https://opentelemetry.io/docs/specs/semconv/http/http-spans/#name
             - HTTP Attributes: https://opentelemetry.io/docs/specs/semconv/attributes-registry/http/
             */
            let name = httpMethod.isEmpty ? url.path : "\(httpMethod) \(url.path)"
            let networkSpan = self.otel.buildSpan(name: name,
                                                  type: .networkHTTP,
                                                  attributes: attributes)
            self.spans[task] = networkSpan.startSpan()
        }
    }

    func finish(task: URLSessionTask, data: Data?, error: (any Error)?) {
        queue.async {
            guard self.shouldTrack() else {
                return
            }

            guard let span = self.spans.removeValue(forKey: task) else {
                return
            }

            if let response = task.response as? HTTPURLResponse {
                span.setAttribute(key: SpanAttribute.statusCode, value: response.statusCode)
            }

            if let data = data {
                let totalData = task.embraceData ?? data
                span.setAttribute(key: SpanAttribute.responseSize, value: totalData.count)
            }

            if let error = error {
                // Should this be something else?
                let nsError = error as NSError
                span.setAttribute(key: SpanAttribute.errorType, value: nsError.domain)
                span.setAttribute(key: SpanAttribute.errorCode, value: nsError.code)
                span.setAttribute(key: SpanAttribute.errorMessage, value: error.localizedDescription)
            }

            span.end()
        }
    }

    func changedState(to captureServiceState: CaptureServiceState) {
        state = captureServiceState == .listening ? .listening : .paused
    }
}

private extension DefaultURLSessionTaskHandler {
    func shouldTrack() -> Bool { state == .listening }
}

private extension DefaultURLSessionTaskHandler {
    static func queue() -> DispatchQueue {
        .init(label: "com.embrace.URLSessionTaskHandler", qos: .utility)
    }
}
