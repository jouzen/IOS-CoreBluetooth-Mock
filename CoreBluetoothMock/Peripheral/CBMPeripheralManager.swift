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

/// An object that manages and advertises peripheral services exposed by this app.
///
/// `CBMPeripheralManager` objects manage published services within the local peripheral
/// device’s Generic Attribute Profile (GATT) database and advertise these services to central
/// devices (represented by ``CBMCentral`` objects). While a service is in the database, any
/// connected central can see and connect to it.
///
/// Use ``CBMPeripheralManagerFactory`` to create an instance of the peripheral manager.
/// On a simulator, or when mocking is forced, a ``CBMPeripheralManagerMock`` is returned,
/// which interacts with simulated centrals defined using ``CBMCentralSpec``.
open class CBMPeripheralManager: NSObject {

    /// A dummy initializer that allows overriding ``CBMPeripheralManager`` class and also
    /// gives a warning when trying to migrate from native `CBPeripheralManager`
    /// to ``CBMPeripheralManager``. This method does nothing.
    ///
    /// If you migrated to CoreBluetooth Mock and are getting an error with
    /// instantiating a ``CBMPeripheralManager`` instance, use
    /// ``CBMPeripheralManagerFactory/instance(delegate:queue:forceMock:)`` instead.
    public init(_ dummy: Bool) {
        // No-op.
    }

    open weak var delegate: CBMPeripheralManagerDelegate?

    open var state: CBMManagerState { return .unknown }

    @objc dynamic open internal(set) var isAdvertising: Bool = false

    @available(iOS, introduced: 13.0, deprecated: 13.1)
    @available(macOS, introduced: 10.15)
    @available(tvOS, introduced: 13.0, deprecated: 13.1)
    @available(watchOS, introduced: 6.0, deprecated: 6.1)
    open var authorization: CBMManagerAuthorization { .notDetermined }

    /// The current authorization status for using Bluetooth.
    ///
    /// Check this property in your implementation of the delegate methods
    /// ``CBMCentralManagerDelegate/centralManagerDidUpdateState(_:)``
    /// and ``CBMPeripheralManagerDelegate/peripheralManagerDidUpdateState(_:)``
    /// to determine whether your app can use Core Bluetooth. You can also
    /// use it to check the app’s authorization status before creating a `CBManager` instance.
    ///
    /// The initial value of this property is `CBMManagerAuthorization.notDetermined`.
    ///
    /// - Note:
    /// This method returns the value set as ``CBMCentralManagerMock/simulateAuthorization(_:)``
    /// or, if set to `nil`, the native result returned by `CBPeripheralManager`.
    @available(iOS 13.1, macOS 10.15, tvOS 13.1, watchOS 6.1, *)
    open class var authorization: CBMManagerAuthorization {
        if let rawValue = CBMCentralManagerMock.bluetoothAuthorization,
           let authorization = CBMManagerAuthorization(rawValue: rawValue) {
            return authorization
        } else {
            return CBPeripheralManager.authorization
        }
    }

    /// Advertises peripheral manager data.
    ///
    /// When you start advertising peripheral data, the peripheral manager calls the
    /// ``CBMPeripheralManagerDelegate/peripheralManagerDidStartAdvertising(_:error:)-4p0nc``
    /// method of its delegate object.
    ///
    /// Core Bluetooth advertises data on a “best effort” basis, due to limited space and
    /// because there may be multiple apps advertising simultaneously. While in the foreground,
    /// your app can use up to 28 bytes of space in the initial advertisement data for any
    /// combination of the supported advertising data keys. If no space remains in the initial
    /// advertisement data, there’s an additional 10 bytes of space in the scan response,
    /// usable only for the local name (represented by the value of the
    /// ``CBMAdvertisementDataLocalNameKey`` key).
    ///
    /// - Important: Only two of the keys are supported: ``CBMAdvertisementDataLocalNameKey``
    ///              and ``CBMAdvertisementDataServiceUUIDsKey``. Other keys are ignored.
    /// - Parameter advertisementData: An optional dictionary containing the data you want to advertise.
    open func startAdvertising(_ advertisementData: [String : Any]?) {
        // Empty default implementation.
    }

    /// Stops advertising peripheral manager data.
    ///
    /// Call this method when you no longer want to advertise peripheral manager data.
    open func stopAdvertising() {
        // Empty default implementation.
    }

    /// Sets the desired connection latency for an existing connection to a central device.
    ///
    /// The connection latency changes depending on any pending updates to the peripheral
    /// manager’s database. Set the connection latency to allow the peripheral manager to
    /// update the peripheral manager’s connected centrals more or less often.
    ///
    /// The peripheral manager’s connection latency for a central device is determined by
    /// the value of ``CBMPeripheralManagerConnectionLatency``. The peripheral manager
    /// will attempt to maintain a connection latency that is as close as possible to the
    /// desired latency.
    /// - Parameters:
    ///   - latency: The desired connection latency.
    ///   - central: A connected central device.
    open func setDesiredConnectionLatency(_ latency: CBMPeripheralManagerConnectionLatency,
                                          for central: CBMCentral) {
        // Empty default implementation.
    }

    /// Publishes a service and any of its associated characteristics and characteristic
    /// descriptors to the local GATT database.
    ///
    /// When you add a service to the database, the peripheral manager calls the
    /// ``CBMPeripheralManagerDelegate/peripheralManager(_:didAdd:error:)-9ex2j``
    /// method of its delegate object. If the service contains any included services,
    /// publish them first.
    ///
    /// - Important: All characteristics of the service must be ``CBMMutableCharacteristic``
    ///              objects. Characteristics with cached values must be read-only.
    /// - Parameter service: The service you want to publish.
    open func add(_ service: CBMMutableService) {
        // Empty default implementation.
    }

    /// Removes a specified published service from the local GATT database.
    ///
    /// Because the peripheral manager may have multiple references to a given service
    /// (for example, when a service is included in another service), removing a service
    /// removes only the reference to the service.
    /// - Parameter service: The service you want to remove.
    open func remove(_ service: CBMMutableService) {
        // Empty default implementation.
    }

    /// Removes all published services from the local GATT database.
    open func removeAllServices() {
        // Empty default implementation.
    }

    /// Responds to a read or write request from a connected central.
    ///
    /// When the peripheral manager receives a read or write request from a connected central,
    /// it calls the ``CBMPeripheralManagerDelegate/peripheralManager(_:didReceiveRead:)-8sx65``
    /// or ``CBMPeripheralManagerDelegate/peripheralManager(_:didReceiveWrite:)-1d33g``
    /// method of its delegate object. Call this method exactly once for each request
    /// (or for the first request in case of multiple write requests).
    /// - Parameters:
    ///   - request: The read or write request received from the connected central.
    ///   - result: The result of attempting to fulfill the request.
    open func respond(to request: CBMATTRequest, withResult result: CBMATTError.Code) {
        // Empty default implementation.
    }

    /// Sends an updated characteristic value to one or more subscribed centrals, using a
    /// notification or indication.
    ///
    /// If the underlying transmit queue is full, the method returns `false`. When space
    /// becomes available, the peripheral manager calls the
    /// ``CBMPeripheralManagerDelegate/peripheralManagerIsReady(toUpdateSubscribers:)-1n35f``
    /// method of its delegate object.
    /// - Parameters:
    ///   - value: The value to send.
    ///   - characteristic: The characteristic whose value has changed.
    ///   - centrals: A list of centrals that have subscribed to the characteristic and
    ///               should be notified. If `nil`, all subscribed centrals are updated.
    /// - Returns: `true` if the update was sent, `false` if the transmit queue is full.
    open func updateValue(_ value: Data,
                          for characteristic: CBMMutableCharacteristic,
                          onSubscribedCentrals centrals: [CBMCentral]?) -> Bool {
        // Empty default implementation.
        return false
    }

    /// Publishes an L2CAP channel over the peripheral manager.
    ///
    /// When the peripheral manager publishes the channel, it calls the
    /// ``CBMPeripheralManagerDelegate/peripheralManager(_:didPublishL2CAPChannel:error:)-3s7pv``
    /// method of its delegate object.
    /// - Parameter encryptionRequired: `true` if the channel requires encryption.
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func publishL2CAPChannel(withEncryption encryptionRequired: Bool) {
        // Empty default implementation.
    }

    /// Removes an L2CAP channel over the peripheral manager.
    ///
    /// When the peripheral manager unpublishes the channel, it calls the
    /// ``CBMPeripheralManagerDelegate/peripheralManager(_:didUnpublishL2CAPChannel:error:)-7t9nh``
    /// method of its delegate object.
    /// - Parameter PSM: The PSM of the channel to unpublish.
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func unpublishL2CAPChannel(_ PSM: CBML2CAPPSM) {
        // Empty default implementation.
    }
}
