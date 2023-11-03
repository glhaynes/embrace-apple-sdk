//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import Security

class KeychainAccess {

    static let kEmbraceKeychainService = "io.embrace.keys"
    static let kEmbraceDeviceId = "io.embrace.deviceid_v3"

    private init() { }

    static var keychain: KeychainInterface = DefaultKeychainInterface()

    static var deviceId: UUID? {
        let pair = keychain.valueFor(service: kEmbraceKeychainService as CFString, account: kEmbraceDeviceId as CFString)
        if let _deviceId = pair.value {
            return UUID(uuidString: _deviceId)
        }

        let newId = UUID()
        let status = keychain.setValue(service: kEmbraceKeychainService as CFString, account: kEmbraceDeviceId as CFString, value: newId.uuidString)

        if status != errSecSuccess {
            if let err = SecCopyErrorMessageString(status, nil) {
                print("Write failed: \(err)")
            }
        }

        return newId
    }
}
