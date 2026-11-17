/*
* Copyright (c) 2026, Nordic Semiconductor
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without modification,
* are permitted provided that the following conditions are met:
*
* 1. Redistributions of source code must retain the above copyright notice, this
*    list of conditions and the following disclaimer.
*
* 2. Redistributions in binary form must reproduce the above copyright notice, this
*    list of conditions and the following disclaimer in the documentation and/or
*    other materials provided with the distribution.
*
* 3. Neither the name of the copyright holder nor the names of its contributors may
*    be used to endorse or promote products derived from this software without
*    specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
* IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
* INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
* PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

import XCTest
import CoreBluetooth
@testable import CoreBluetoothMock

/// `CBPeripheral` cannot be created in a test, so these tests check the attribute type guard the native peripheral
/// delegate wrapper applies to every characteristic and descriptor callback.
class NativeAttributeTypeTest: XCTestCase {

    private let characteristic = CBMutableCharacteristic(type: CBUUID(string: "2A37"),
                                                         properties: [.notify],
                                                         value: nil,
                                                         permissions: [.readable])

    func testServicePassedAsCharacteristicIsRejected() {
        let service = CBMutableService(type: CBUUID(string: "180D"), primary: true)
        // The object Core Bluetooth passed to a characteristic callback on iOS 27 after the GATT handles moved.
        let serviceTypedAsCharacteristic = unsafeBitCast(service, to: CBCharacteristic.self)

        XCTAssertNil(nativeAttribute(serviceTypedAsCharacteristic, ifKindOf: CBCharacteristic.self))
    }

    func testCharacteristicIsAccepted() {
        let result = nativeAttribute(characteristic as CBCharacteristic, ifKindOf: CBCharacteristic.self)

        XCTAssertTrue(result === characteristic)
    }

    func testCharacteristicPassedAsDescriptorIsRejected() {
        let characteristicTypedAsDescriptor = unsafeBitCast(characteristic, to: CBDescriptor.self)

        XCTAssertNil(nativeAttribute(characteristicTypedAsDescriptor, ifKindOf: CBDescriptor.self))
    }

    func testDescriptorIsAccepted() {
        let descriptor = CBMutableDescriptor(type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                                             value: "Heart Rate")

        let result = nativeAttribute(descriptor as CBDescriptor, ifKindOf: CBDescriptor.self)

        XCTAssertTrue(result === descriptor)
    }

    func testMissingAttributeIsRejected() {
        XCTAssertNil(nativeAttribute(nil as CBCharacteristic?, ifKindOf: CBCharacteristic.self))
    }
}
