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

import CoreBluetooth

/// A service with characteristics and included services that you can add to a local peripheral.
///
/// `CBMMutableService` objects represent services published by the local device using
/// ``CBMPeripheralManager``. The characteristics of a mutable service must be
/// ``CBMMutableCharacteristic`` objects.
open class CBMMutableService: CBMService {

    /// A list of included services.
    ///
    /// Included services must be published using ``CBMPeripheralManager/add(_:)``
    /// before the service which includes them.
    open override var includedServices: [CBMService]? {
        get { return _includedServices }
        set { _includedServices = newValue }
    }

    /// A list of characteristics of the service.
    ///
    /// The characteristics must be ``CBMMutableCharacteristic`` objects.
    open override var characteristics: [CBMCharacteristic]? {
        get { return _characteristics }
        set {
            _characteristics = newValue
            // Assign parent service instance.
            _characteristics?.forEach { $0.service = self }
        }
    }

    /// Returns a service, initialized with a service type and UUID.
    /// - Parameters:
    ///   - uuid: The Bluetooth UUID of the service.
    ///   - isPrimary: The type of the service (primary or secondary).
    public override init(type uuid: CBMUUID, primary isPrimary: Bool) {
        super.init(type: uuid, primary: isPrimary)
        #if swift(>=5.5)
        // A local service does not belong to any remote peripheral.
        self.peripheral = nil
        #endif
    }

    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? CBMMutableService {
            return identifier == other.identifier
        }
        return false
    }
}

/// A characteristic of a local peripheral’s service.
///
/// `CBMMutableCharacteristic` objects represent characteristics of services published
/// by the local device using ``CBMPeripheralManager``.
///
/// If a characteristic is created with a non-`nil` value, the value is cached and the
/// characteristic must be read-only. Read requests for such characteristics are handled
/// automatically without calling the peripheral manager's delegate.
open class CBMMutableCharacteristic: CBMCharacteristic {

    /// The permissions of the characteristic value.
    open var permissions: CBMAttributePermissions

    /// For notifying characteristics, the set of currently subscribed centrals.
    open internal(set) var subscribedCentrals: [CBMCentral]?

    /// The properties of the characteristic.
    open override var properties: CBMCharacteristicProperties {
        get { return super.properties }
        set { super.properties = newValue }
    }

    /// The value of the characteristic.
    ///
    /// When a value is set, the characteristic must be read-only. The value is
    /// then cached and returned automatically to reading centrals.
    open override var value: Data? {
        get { return super.value }
        set { super.value = newValue }
    }

    /// A list of descriptors of the characteristic.
    open override var descriptors: [CBMDescriptor]? {
        get { return _descriptors }
        set {
            _descriptors = newValue
            // Assign parent characteristic instance.
            _descriptors?.forEach { $0.characteristic = self }
        }
    }

    /// Returns an initialized characteristic.
    /// - Parameters:
    ///   - uuid: The Bluetooth UUID of the characteristic.
    ///   - properties: The properties of the characteristic.
    ///   - value: The characteristic value to be cached. If `nil`, the value will be
    ///            requested from the peripheral manager's delegate whenever a
    ///            central reads it.
    ///   - permissions: The permissions of the characteristic value.
    public init(type uuid: CBMUUID,
                properties: CBMCharacteristicProperties,
                value: Data?,
                permissions: CBMAttributePermissions) {
        self.permissions = permissions
        super.init(type: uuid, properties: properties)
        self.value = value
        #if swift(>=5.5)
        // The service is assigned when the characteristic is added to a service.
        self.service = nil
        #endif
    }

    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? CBMMutableCharacteristic {
            return identifier == other.identifier
        }
        return false
    }
}

/// A descriptor of a local peripheral’s characteristic.
///
/// `CBMMutableDescriptor` objects represent descriptors of characteristics published
/// by the local device using ``CBMPeripheralManager``. The value of a descriptor
/// is required and cannot be updated dynamically once the parent service has been published.
open class CBMMutableDescriptor: CBMDescriptor {

    /// Returns a descriptor, initialized with a descriptor type and value.
    /// - Parameters:
    ///   - uuid: The Bluetooth UUID of the descriptor.
    ///   - value: The value of the descriptor.
    public init(type uuid: CBMUUID, value: Any?) {
        super.init(type: uuid)
        self.value = value
        #if swift(>=5.5)
        // The characteristic is assigned when the descriptor is added to a characteristic.
        self.characteristic = nil
        #endif
    }

    open override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? CBMMutableDescriptor {
            return identifier == other.identifier
        }
        return false
    }
}
