//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceStorage
import EmbraceOTel

struct SessionPayload: Encodable {
    let messageFormatVersion: Int
    let sessionInfo: SessionInfoPayload
    let appInfo: AppInfoPayload
    let deviceInfo: DeviceInfoPayload
    let userInfo: UserInfoPayload
    let sessionType: String = "en"
    let sessionTerminated: Bool = false
    let cleanExit: Bool = true
    let coldStart: Bool = false
    let spans: [SpanPayload]
    let spanSnapshots: [SpanPayload]

    enum CodingKeys: String, CodingKey {
        case messageFormatVersion = "v"
        case sessionInfo = "s"
        case appInfo = "a"
        case deviceInfo = "d"
        case userInfo = "u"
        case spans = "spans"
        case spanSnapshots = "span_snapshots"
        case sessionType = "ty"
        case sessionTerminated = "tr"
        case cleanExit = "ce"
        case coldStart = "cs"
    }

    init(
        from sessionRecord: SessionRecord,
        resourceFetcher: EmbraceStorageResourceFetcher,
        spans: [SpanPayload] = [],
        spanSnapshots: [SpanPayload] = [],
        counter: Int = -1
    ) {
        let resources = PayloadUtils.fetchResources(from: resourceFetcher, sessionId: sessionRecord.id)

        self.messageFormatVersion = 15
        self.sessionInfo = SessionInfoPayload(from: sessionRecord, counter: counter)
        self.appInfo = AppInfoPayload(with: resources)
        self.deviceInfo = DeviceInfoPayload(with: resources)
        self.userInfo = UserInfoPayload(with: resources)
        self.spans = spans
        self.spanSnapshots = spanSnapshots
    }
}
