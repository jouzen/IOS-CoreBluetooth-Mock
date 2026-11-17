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

        XCTAssertNil(nativeAttribute(serviceTypedAsCharacteristic))
    }

    func testCharacteristicIsAccepted() {
        let result = nativeAttribute(characteristic as CBCharacteristic)

        XCTAssertTrue(result === characteristic)
    }

    func testCharacteristicPassedAsDescriptorIsRejected() {
        let characteristicTypedAsDescriptor = unsafeBitCast(characteristic, to: CBDescriptor.self)

        XCTAssertNil(nativeAttribute(characteristicTypedAsDescriptor))
    }

    func testDescriptorIsAccepted() {
        let descriptor = CBMutableDescriptor(type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                                             value: "Heart Rate")

        let result = nativeAttribute(descriptor as CBDescriptor)

        XCTAssertTrue(result === descriptor)
    }

    func testMissingAttributeIsRejected() {
        XCTAssertNil(nativeAttribute(nil as CBCharacteristic?))
    }

    // MARK: - Attribute arrays

    // Key-value coding stores the mixed array in the attribute's instance variable as is, so reading the property
    // returns a bridged Swift array whose elements are checked only when read, like the arrays Core Bluetooth
    // returned in the field. Iterating it directly terminates the test with "NSArray element failed to match the
    // Swift Array Element type".

    private let otherService = CBMutableService(type: CBUUID(string: "180F"), primary: false)
    private let descriptor = CBMutableDescriptor(type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                                                 value: "Heart Rate")

    /// A service whose included services and characteristics each hold one element of another class.
    private func serviceWithMixedArrays() -> CBMutableService {
        let service = CBMutableService(type: CBUUID(string: "180D"), primary: true)
        service.setValue(NSArray(array: [otherService, characteristic]), forKey: "includedServices")
        service.setValue(NSArray(array: [otherService, characteristic]), forKey: "_characteristics")
        return service
    }

    /// A characteristic whose descriptors hold one element of another class.
    private func characteristicWithMixedDescriptors() -> CBMutableCharacteristic {
        let characteristic = CBMutableCharacteristic(type: CBUUID(string: "2A38"),
                                                     properties: [.read],
                                                     value: nil,
                                                     permissions: [.readable])
        characteristic.setValue(NSArray(array: [otherService, descriptor]), forKey: "_descriptors")
        return characteristic
    }

    func testCharacteristicInServicesIsDropped() {
        let result = nativeAttributes(serviceWithMixedArrays().includedServices)

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first === otherService)
    }

    func testServiceInCharacteristicsIsDropped() {
        let result = nativeAttributes(serviceWithMixedArrays().characteristics)

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first === characteristic)
    }

    func testServiceInDescriptorsIsDropped() {
        let result = nativeAttributes(characteristicWithMixedDescriptors().descriptors)

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first === descriptor)
    }

    func testMissingArrayIsEmpty() {
        XCTAssertTrue(nativeAttributes(nil as [CBService]?).isEmpty)
    }

    // MARK: - Native attribute wrappers

    func testServiceWrapperDropsAttributesOfAnotherClass() {
        let service = serviceWithMixedArrays()

        let wrapper = CBMServiceNative(service, in: CBMPeripheralPreview(Blinky().spec))
        wrapper.update(service)

        XCTAssertEqual(wrapper.includedServices?.count, 1)
        XCTAssertEqual(wrapper.characteristics?.count, 1)
    }

    func testCharacteristicWrapperDropsDescriptorsOfAnotherClass() {
        let characteristic = characteristicWithMixedDescriptors()
        let service = CBMServiceNative(CBMutableService(type: CBUUID(string: "180D"), primary: true),
                                       in: CBMPeripheralPreview(Blinky().spec))

        let wrapper = CBMCharacteristicNative(characteristic, in: service)
        wrapper.update(characteristic)

        XCTAssertEqual(wrapper.descriptors?.count, 1)
    }
}
