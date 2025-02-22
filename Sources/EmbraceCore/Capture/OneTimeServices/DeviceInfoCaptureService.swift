//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import EmbraceCommon
import EmbraceObjCUtils

@objc public class DeviceInfoCaptureService: NSObject, CaptureService {
    typealias Keys = DeviceResourceKey

    let resourceHandler: CaptureServiceResourceHandlerType

    init(resourceHandler: CaptureServiceResourceHandlerType = CaptureServiceResourceHandler()) {
        self.resourceHandler = resourceHandler
    }

    public func setup(context: EmbraceCommon.CaptureServiceContext) { }

    public func start() {
        let isJailbroken = EMBDevice.isJailbroken
        let locale = EMBDevice.locale
        let timezoneDescription = EMBDevice.timezoneDescription
        let totalDiskSpace = EMBDevice.totalDiskSpace
        let operatingSystemVersion = EMBDevice.operatingSystemVersion
        let operatingSystemBuild = EMBDevice.operatingSystemBuild
        let screenResolution = EMBDevice.screenResolution
        let deviceModel = EMBDevice.model
        let osVariant =  EMBDevice.operatingSystemType
        do {
            try resourceHandler.addResource(key: Keys.isJailbroken.rawValue, value: String(isJailbroken))
            try resourceHandler.addResource(key: Keys.locale.rawValue, value: locale)
            try resourceHandler.addResource(key: Keys.timezone.rawValue, value: timezoneDescription)
            try resourceHandler.addResource(key: Keys.totalDiskSpace.rawValue, value: totalDiskSpace.intValue)
            try resourceHandler.addResource(key: Keys.OSVersion.rawValue, value: operatingSystemVersion)
            try resourceHandler.addResource(key: Keys.OSBuild.rawValue, value: operatingSystemBuild)
            try resourceHandler.addResource(key: Keys.screenResolution.rawValue, value: screenResolution ?? "")
            try resourceHandler.addResource(key: Keys.model.rawValue, value: deviceModel)
            try resourceHandler.addResource(key: Keys.osVariant.rawValue, value: osVariant)
        } catch let e {
            ConsoleLog.error("Failed to capture device info metadata \(e.localizedDescription)")
        }
    }

    public func stop() {}

}
