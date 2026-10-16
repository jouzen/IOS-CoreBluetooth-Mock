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

/// Mock implementation of the ``CBMPeripheralManager``.
///
/// This implementation will interact only with mock centrals created using
/// ``CBMCentralSpec``. The state of the Bluetooth adapter is shared with
/// ``CBMCentralManagerMock`` and can be controlled using
/// ``CBMCentralManagerMock/simulatePowerOn()``, ``CBMCentralManagerMock/simulatePowerOff()``
/// and other simulation methods.
open class CBMPeripheralManagerMock: CBMPeripheralManager {
    private static var managers: [WeakRef<CBMPeripheralManagerMock>] = []
    private static var centrals: [WeakRef<CBMCentralSpec>] = []
    private static let mutex: DispatchQueue = DispatchQueue(label: "Mutex")

    /// Size of the transmit queue for notifications and indications.
    /// Only this many updates can be sent without waiting for
    /// ``CBMPeripheralManagerDelegate/peripheralManagerIsReady(toUpdateSubscribers:)-1n35f``.
    private static let updateQueueSize = 20

    /// The dispatch queue used for all delegate callbacks.
    internal let queue: DispatchQueue
    /// A serial queue synchronizing access to the state below, including
    /// `subscribedCentrals` of published characteristics.
    ///
    /// Blocks executed on it must not call the delegate, nor any other
    /// user-provided code, as such code may call back into the manager.
    private let mutex: DispatchQueue = DispatchQueue(label: "Mutex")

    private var services: [CBMMutableService] = []
    private var advertisementData: [String : Any]?
    /// A flag indicating whether the manager is advertising.
    ///
    /// ``CBMPeripheralManager/isAdvertising`` mirrors this flag. It is set outside
    /// of the ``mutex``, as setting it calls KVO observers.
    private var advertising: Bool = false
    /// A map of centrals known to this peripheral manager.
    private var centrals: [UUID : CBMCentralMock] = [:]
    /// A list of requests that have not been responded to yet.
    private var pendingRequests: [CBMATTRequestMock] = []
    /// Number of updates in the transmit queue.
    private var pendingUpdates: Int = 0
    /// A flag set to true when ``updateValue(_:for:onSubscribedCentrals:)``
    /// returned `false` due to the transmit queue being full.
    private var readyNotificationPending: Bool = false
    /// The restored state, passed to the delegate on the ``queue`` once the
    /// manager is initialized.
    private var restoredState: [String : Any]?

    /// This simulation method is called when a mock peripheral manager was
    /// created with an option to restore the state
    /// (``CBMPeripheralManagerOptionRestoreIdentifierKey``).
    ///
    /// The returned map, if not `nil`, will be passed to
    /// ``CBMPeripheralManagerDelegate/peripheralManager(_:willRestoreState:)-4tv1g`` before creation.
    /// - SeeAlso: ``CBMPeripheralManagerRestoredStateServicesKey``
    /// - SeeAlso: ``CBMPeripheralManagerRestoredStateAdvertisementDataKey``
    public static var simulateStateRestoration: ((_ identifierKey: String) -> [String : Any]?)?

    public init() {
        self.queue = DispatchQueue.main
        super.init(true)
        initialize()
    }

    public init(delegate: CBMPeripheralManagerDelegate?,
                queue: DispatchQueue?) {
        self.queue = queue ?? DispatchQueue.main
        super.init(true)
        self.delegate = delegate
        initialize()
    }

    public init(delegate: CBMPeripheralManagerDelegate?,
                queue: DispatchQueue?,
                options: [String : Any]?) {
        self.queue = queue ?? DispatchQueue.main
        super.init(true)
        self.delegate = delegate
        if let options = options,
           let identifierKey = options[CBMPeripheralManagerOptionRestoreIdentifierKey] as? String,
           let dict = CBMPeripheralManagerMock.simulateStateRestoration?(identifierKey) {
            var state: [String : Any] = [:]
            if let services = dict[CBMPeripheralManagerRestoredStateServicesKey] as? [CBMMutableService] {
                state[CBMPeripheralManagerRestoredStateServicesKey] = services
                self.services = services
            }
            if let advertisementData = dict[CBMPeripheralManagerRestoredStateAdvertisementDataKey] as? [String : Any] {
                state[CBMPeripheralManagerRestoredStateAdvertisementDataKey] = advertisementData
                self.advertisementData = advertisementData
                self.advertising = true
                self.isAdvertising = true
            }
            self.restoredState = state
        }
        initialize()
    }

    open override var state: CBMManagerState {
        guard initialized else {
            return .unknown
        }
        guard CBMCentralManagerMock.isAuthorized else {
            return .unauthorized
        }
        return CBMCentralManagerMock.managerState
    }

    @available(iOS, introduced: 13.0, deprecated: 13.1)
    @available(macOS, introduced: 10.15)
    @available(tvOS, introduced: 13.0, deprecated: 13.1)
    @available(watchOS, introduced: 6.0, deprecated: 6.1)
    open override var authorization: CBMManagerAuthorization {
        if let rawValue = CBMCentralManagerMock.bluetoothAuthorization,
           let authorization = CBMManagerAuthorization(rawValue: rawValue) {
            return authorization
        } else {
            // If `simulateAuthorization(:)` was not called, .allowedAlways is assumed.
            return .allowedAlways
        }
    }

    @available(iOS 13.1, macOS 10.15, tvOS 13.1, watchOS 6.1, *)
    open override class var authorization: CBMManagerAuthorization {
        if let rawValue = CBMCentralManagerMock.bluetoothAuthorization,
           let authorization = CBMManagerAuthorization(rawValue: rawValue) {
            return authorization
        } else {
            // If `simulateAuthorization(:)` was not called, .allowedAlways is assumed.
            return .allowedAlways
        }
    }

    open override func startAdvertising(_ advertisementData: [String : Any]?) {
        guard ensurePoweredOn() else { return }

        // Only the local name and the list of service UUIDs are supported.
        var data: [String : Any] = [:]
        if let name = advertisementData?[CBMAdvertisementDataLocalNameKey] as? String {
            data[CBMAdvertisementDataLocalNameKey] = name
        }
        if let serviceUUIDs = advertisementData?[CBMAdvertisementDataServiceUUIDsKey] as? [CBMUUID] {
            data[CBMAdvertisementDataServiceUUIDsKey] = serviceUUIDs
        }

        let alreadyAdvertising: Bool = mutex.sync {
            guard !advertising else {
                return true
            }
            self.advertisementData = data
            return false
        }
        guard !alreadyAdvertising else {
            queue.async { [weak self] in
                if let self = self {
                    self.delegate?.peripheralManagerDidStartAdvertising(self, error: CBMError(.alreadyAdvertising))
                }
            }
            return
        }

        let unsupportedKeys = advertisementData?.keys.filter { key in
            key != CBMAdvertisementDataLocalNameKey && key != CBMAdvertisementDataServiceUUIDsKey
        } ?? []
        if !unsupportedKeys.isEmpty {
            NSLog("Warning: Advertisement data keys \(unsupportedKeys) are not supported and will be ignored")
        }

        queue.async { [weak self] in
            guard let self = self, self.state == .poweredOn else {
                return
            }
            let started: Bool = self.mutex.sync {
                guard self.advertisementData != nil else {
                    return false
                }
                self.advertising = true
                return true
            }
            guard started else {
                return
            }
            self.isAdvertising = true
            self.delegate?.peripheralManagerDidStartAdvertising(self, error: nil)
        }
    }

    open override func stopAdvertising() {
        guard ensurePoweredOn() else { return }
        mutex.sync {
            advertising = false
            advertisementData = nil
        }
        isAdvertising = false
    }

    open override func setDesiredConnectionLatency(_ latency: CBMPeripheralManagerConnectionLatency,
                                                   for central: CBMCentral) {
        guard ensurePoweredOn() else { return }

        guard let central = central as? CBMCentralMock,
              mutex.sync(execute: { centrals[central.identifier] === central }) else {
            NSLog("[CoreBluetoothMock] API MISUSE: Central \(central.identifier) not known")
            return
        }

        central.spec.desiredConnectionLatency = latency
    }

    open override func add(_ service: CBMMutableService) {
        guard ensurePoweredOn() else { return }

        guard let characteristics = (service.characteristics ?? []) as? [CBMMutableCharacteristic] else {
            NSLog("[CoreBluetoothMock] API MISUSE: All characteristics of service \(service.uuid) must be CBMMutableCharacteristic")
            notifyDidAddServiceCallback(service, error: CBMError(.invalidParameters))
            return
        }

        // Characteristics with cached values must be read-only.
        let readOnly = characteristics.allSatisfy { characteristic in
            characteristic.value == nil ||
            (characteristic.properties.isSubset(of: .read) &&
             characteristic.permissions.isSubset(of: [.readable, .readEncryptionRequired]))
        }
        guard readOnly else {
            NSLog("[CoreBluetoothMock] API MISUSE: Characteristics with cached values must be read-only")
            notifyDidAddServiceCallback(service, error: CBMError(.invalidParameters))
            return
        }

        let added: Bool = mutex.sync {
            guard !services.contains(where: { $0 === service }) else {
                return false
            }
            services.append(service)
            return true
        }
        guard added else {
            NSLog("[CoreBluetoothMock] API MISUSE: Service \(service.uuid) has already been added")
            notifyDidAddServiceCallback(service, error: CBMError(.invalidParameters))
            return
        }
        notifyDidAddServiceCallback(service, error: nil)
    }

    open override func remove(_ service: CBMMutableService) {
        guard ensurePoweredOn() else { return }

        mutex.sync {
            guard let index = services.firstIndex(where: { $0 === service }) else {
                return
            }
            services.remove(at: index)
            unsubscribeAllCentrals(from: service)
        }
    }

    open override func removeAllServices() {
        guard ensurePoweredOn() else { return }
        mutex.sync {
            services.forEach { unsubscribeAllCentrals(from: $0) }
            services.removeAll()
        }
    }

    open override func respond(to request: CBMATTRequest, withResult result: CBMATTError.Code) {
        guard ensurePoweredOn() else { return }

        let pendingRequest: CBMATTRequestMock? = mutex.sync {
            guard
                let request = request as? CBMATTRequestMock,
                let index = pendingRequests.firstIndex(where: { $0 === request })
            else {
                return nil
            }
            return pendingRequests.remove(at: index)
        }
        guard let pending = pendingRequest else {
            NSLog("[CoreBluetoothMock] API MISUSE: \(request) is not pending, or has already been responded to")
            return
        }
        pending.respond(result)
    }

    open override func updateValue(_ value: Data,
                                   for characteristic: CBMMutableCharacteristic,
                                   onSubscribedCentrals centrals: [CBMCentral]?) -> Bool {
        guard ensurePoweredOn() else { return false }

        let subscribers: [CBMCentral]? = mutex.sync {
            guard owns(characteristic) else {
                return nil
            }
            return characteristic.subscribedCentrals ?? []
        }
        guard let subscribedCentrals = subscribers else {
            NSLog("[CoreBluetoothMock] API MISUSE: Characteristic \(characteristic.uuid) has not been added to \(self)")
            return false
        }

        let targets = subscribedCentrals
            .compactMap { $0 as? CBMCentralMock }
            .filter { central in
                centrals?.contains(where: { $0.identifier == central.identifier }) ?? true
            }
            .filter { $0.spec.isConnected }

        guard !targets.isEmpty else { return true }

        // Emulate the limited size of the transmit queue.
        let accepted: Bool = mutex.sync {
            guard pendingUpdates < CBMPeripheralManagerMock.updateQueueSize else {
                readyNotificationPending = true
                return false
            }
            pendingUpdates += 1
            return true
        }
        guard accepted else { return false }

        let delivery = DispatchGroup()
        targets.forEach { central in
            let spec = central.spec
            let data = Data(value.prefix(central.maximumUpdateValueLength))
            delivery.enter()
            queue.asyncAfter(deadline: .now() + spec.connectionInterval) { [weak self] in
                defer { delivery.leave() }
                guard let self = self, self.state == .poweredOn, spec.isConnected,
                      self.mutex.sync(execute: {
                          self.owns(characteristic) && self.isSubscribed(central, to: characteristic)
                      }) else {
                    return
                }
                spec.delegate?.central(spec, didReceiveUpdate: data, for: characteristic)
            }
        }

        // When the update is sent to all centrals, there is space in the transmit queue again.
        delivery.notify(queue: queue) { [weak self] in
            guard
                let self = self,
                self.state == .poweredOn
            else { return }
            let ready: Bool = self.mutex.sync {
                self.pendingUpdates -= 1
                guard self.readyNotificationPending,
                      self.pendingUpdates < CBMPeripheralManagerMock.updateQueueSize else {
                    return false
                }
                self.readyNotificationPending = false
                return true
            }
            if ready {
                self.delegate?.peripheralManagerIsReady(toUpdateSubscribers: self)
            }
        }
        return true
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open override func publishL2CAPChannel(withEncryption encryptionRequired: Bool) {
        fatalError("L2CAP mock is not implemented")
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open override func unpublishL2CAPChannel(_ PSM: CBML2CAPPSM) {
        fatalError("L2CAP mock is not implemented")
    }

    open override var debugDescription: String {
        return mutex.sync {
            "<CBMPeripheralManager: services: \(services.count), advertising: \(advertising)>"
        }
    }
}

/// used by CBMCentralManagerMock
extension CBMPeripheralManagerMock {
    internal static func notifyManagers() {
        self.existingManagers.forEach { manager in
            manager.queue.async {
                if manager.state != .poweredOn {
                    // ...stop advertising and remove all services if state changed
                    // to any other state than `.poweredOn`.
                    manager.reset()
                }
                manager.delegate?.peripheralManagerDidUpdateState(manager)
            }
        }
        if CBMCentralManagerMock.managerState != .poweredOn {
            disconnectAllCentrals()
        }
        mutex.sync {
            managers.removeAll { $0.ref == nil }
        }
    }

    /// This method is called from ``CBMCentralManagerMock/tearDownSimulation()``.
    internal static func tearDown() {
        mutex.sync {
            managers.removeAll()
        }
        disconnectAllCentrals()
    }
}

/// used by CBMCentralSpec
extension CBMPeripheralManagerMock {
    internal var currentAdvertisementData: [String : Any]? {
        return mutex.sync { advertising ? advertisementData : nil }
    }

    internal var publishedServices: [CBMMutableService] {
        return mutex.sync { services }
    }

    internal static func centralDidConnect(_ central: CBMCentralSpec) {
        mutex.sync {
            if !centrals.contains(where: { $0.ref === central }) {
                centrals.append(WeakRef(central))
            }
        }
    }

    internal static func centralDidDisconnect(_ central: CBMCentralSpec) {
        mutex.sync {
            centrals.removeAll { $0.ref == nil || $0.ref === central }
        }
        existingManagers.forEach { manager in
            manager.central(didDisconnect: central)
        }
    }

    internal static func manager(owning characteristic: CBMCharacteristic) -> CBMPeripheralManagerMock? {
        return existingManagers.first { manager in
            manager.mutex.sync { manager.owns(characteristic) }
        }
    }

    internal func central(_ spec: CBMCentralSpec,
                          didSubscribeTo characteristic: CBMMutableCharacteristic) {
        queue.asyncAfter(deadline: .now() + spec.connectionInterval) { [weak self] in
            guard let self = self, self.state == .poweredOn, spec.isConnected else {
                NSLog("Warning: Central \(spec.identifier) is not connected")
                return
            }
            let subscribedCentral: CBMCentralMock? = self.mutex.sync {
                guard self.owns(characteristic) else {
                    return nil
                }
                let central = self.central(for: spec)
                guard !self.isSubscribed(central, to: characteristic) else {
                    return nil
                }
                var subscribedCentrals = characteristic.subscribedCentrals ?? []
                subscribedCentrals.append(central)
                characteristic.subscribedCentrals = subscribedCentrals
                return central
            }
            guard let central = subscribedCentral else {
                return
            }
            self.delegate?.peripheralManager(self, central: central, didSubscribeTo: characteristic)
        }
    }

    internal func central(_ spec: CBMCentralSpec,
                          didUnsubscribeFrom characteristic: CBMMutableCharacteristic) {
        queue.asyncAfter(deadline: .now() + spec.connectionInterval) { [weak self] in
            guard let self = self, self.state == .poweredOn, spec.isConnected else {
                NSLog("Warning: Central \(spec.identifier) is not connected")
                return
            }
            let unsubscribedCentral: CBMCentralMock? = self.mutex.sync {
                guard self.owns(characteristic),
                      let central = self.centrals[spec.identifier],
                      self.isSubscribed(central, to: characteristic) else {
                    return nil
                }
                characteristic.subscribedCentrals?.removeAll { $0.identifier == central.identifier }
                return central
            }
            guard let central = unsubscribedCentral else {
                return
            }
            self.delegate?.peripheralManager(self, central: central, didUnsubscribeFrom: characteristic)
        }
    }

    internal func central(_ spec: CBMCentralSpec,
                          didRequestReadOf characteristic: CBMMutableCharacteristic,
                          offset: Int,
                          completion: @escaping (Result<Data, Error>) -> Void) {
        let queue = self.queue
        let interval = spec.connectionInterval
        let reply: (Result<Data, Error>) -> Void = { result in
            queue.asyncAfter(deadline: .now() + interval) {
                completion(result)
            }
        }
        guard state == .poweredOn, spec.isConnected else {
            reply(.failure(CBMError(.notConnected)))
            return
        }
        
        guard characteristic.properties.contains(.read),
              !characteristic.permissions.isDisjoint(with: [.readable, .readEncryptionRequired]) else {
            reply(.failure(CBMATTError(.readNotPermitted)))
            return
        }
        
        // Characteristics with cached values are handled by the system.
        if let value = characteristic.value {
            guard offset <= value.count else {
                reply(.failure(CBMATTError(.invalidOffset)))
                return
            }
            reply(.success(value.subdata(in: offset..<value.count)))
            return
        }
        
        let central = mutex.sync { self.central(for: spec) }
        let request = CBMATTRequestMock(central: central,
                                        characteristic: characteristic,
                                        offset: offset,
                                        value: nil) { request, result in
            if result == .success {
                reply(.success(request.value ?? Data()))
            } else {
                reply(.failure(CBMATTError(result)))
            }
        }
        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self = self, self.state == .poweredOn, spec.isConnected,
                  self.mutex.sync(execute: { () -> Bool in
                      guard self.owns(characteristic) else {
                          return false
                      }
                      self.pendingRequests.append(request)
                      return true
                  }) else {
                reply(.failure(CBMError(.notConnected)))
                return
            }
            self.delegate?.peripheralManager(self, didReceiveRead: request)
        }
    }

    internal func central(_ spec: CBMCentralSpec,
                          didRequestWrite data: Data,
                          to characteristic: CBMMutableCharacteristic,
                          offset: Int,
                          withResponseCompletion: ((Result<Void, Error>) -> Void)?) {
        let queue = self.queue
        let interval = spec.connectionInterval
        let reply: (Result<Void, Error>) -> Void = { result in
            queue.asyncAfter(deadline: .now() + interval) {
                withResponseCompletion?(result)
            }
        }
        let isWithResponse = withResponseCompletion != nil
        guard state == .poweredOn, spec.isConnected else {
            if isWithResponse {
                reply(.failure(CBMError(.notConnected)))
            } else {
                NSLog("[CoreBluetoothMock] Write command to characteristic \(characteristic.uuid) dropped: not connected")
            }
            return
        }
        
        let permitted = (isWithResponse ?
            characteristic.properties.contains(.write) :
            characteristic.properties.contains(.writeWithoutResponse)) &&
            !characteristic.permissions.isDisjoint(with: [.writeable, .writeEncryptionRequired])
        
        guard permitted else {
            if isWithResponse {
                reply(.failure(CBMATTError(.writeNotPermitted)))
            } else {
                NSLog("[CoreBluetoothMock] Write command to characteristic \(characteristic.uuid) dropped: write without response not permitted")
            }
            return
        }
        // The maximum length of an attribute value is 512 bytes.
        guard offset + data.count <= 512 else {
            if isWithResponse {
                reply(.failure(CBMATTError(.invalidAttributeValueLength)))
            } else {
                NSLog("[CoreBluetoothMock] Write command to characteristic \(characteristic.uuid) dropped: invalid attribute value length")
            }
            return
        }
        let central = mutex.sync { self.central(for: spec) }
        let request = CBMATTRequestMock(central: central,
                                        characteristic: characteristic,
                                        offset: offset,
                                        value: data,
                                        completion: isWithResponse ? { _, result in
            if result == .success {
                reply(.success(()))
            } else {
                reply(.failure(CBMATTError(result)))
            }
        } : nil)
        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            guard let self = self, self.state == .poweredOn, spec.isConnected,
                  self.mutex.sync(execute: { () -> Bool in
                      guard self.owns(characteristic) else {
                          return false
                      }
                      if isWithResponse {
                          self.pendingRequests.append(request)
                      }
                      return true
                  }) else {
                if isWithResponse {
                    reply(.failure(CBMError(.notConnected)))
                } else {
                    NSLog("[CoreBluetoothMock] Write command to characteristic \(characteristic.uuid) dropped: not connected")
                }
                return
            }

            self.delegate?.peripheralManager(self, didReceiveWrite: [request])
        }
    }

    internal static var existingManagers: [CBMPeripheralManagerMock] {
        return mutex.sync {
            managers.compactMap { $0.ref }
        }
    }
}

extension CBMPeripheralManagerMock {
    private static func disconnectAllCentrals() {
        let connectedCentrals: [CBMCentralSpec] = mutex.sync {
            defer { centrals.removeAll() }
            return centrals.compactMap { $0.ref }
        }
        connectedCentrals.forEach { $0.isConnected = false }
    }

    private var initialized: Bool {
        // This method returns true if the manager is added to
        // the list of managers.
        // Calling tearDownSimulation() will remove all managers
        // from that list, making them uninitialized again.
        CBMPeripheralManagerMock.mutex.sync {
            CBMPeripheralManagerMock.managers.contains { $0.ref == self }
        }
    }

    private func initialize() {
        queue.async { [weak self] in
            if let self = self {
                CBMPeripheralManagerMock.mutex.sync {
                    CBMPeripheralManagerMock.managers.append(WeakRef(self))
                }
                if let restoredState = self.restoredState {
                    self.restoredState = nil
                    self.delegate?.peripheralManager(self, willRestoreState: restoredState)
                }
                self.delegate?.peripheralManagerDidUpdateState(self)
            }
        }
    }

    private func ensurePoweredOn() -> Bool {
        guard state == .poweredOn else {
            NSLog("[CoreBluetoothMock] API MISUSE: \(self) can only accept this command while in the powered on state")
            return false
        }
        return true
    }

    private func notifyDidAddServiceCallback(_ service: CBMMutableService, error: Error?) {
        queue.async { [weak self] in
            if let self = self, self.state == .poweredOn {
                self.delegate?.peripheralManager(self, didAdd: service, error: error)
            }
        }
    }

    /// This method is called when the Bluetooth adapter is turned off.
    private func reset() {
        mutex.sync {
            advertising = false
            advertisementData = nil
            services.forEach { unsubscribeAllCentrals(from: $0) }
            services.removeAll()
            pendingRequests.removeAll()
            centrals.removeAll()
            pendingUpdates = 0
            readyNotificationPending = false
        }
        isAdvertising = false
    }

    /// Must be called on the ``mutex``.
    private func unsubscribeAllCentrals(from service: CBMService) {
        dispatchPrecondition(condition: .onQueue(mutex))
        service.characteristics?
            .compactMap { $0 as? CBMMutableCharacteristic }
            .forEach { $0.subscribedCentrals = nil }
    }

    /// Must be called on the ``mutex``.
    private func owns(_ characteristic: CBMCharacteristic) -> Bool {
        dispatchPrecondition(condition: .onQueue(mutex))
        return services.contains { service in
            service.characteristics?.contains { $0 === characteristic } ?? false
        }
    }

    /// Must be called on the ``mutex``.
    private func isSubscribed(_ central: CBMCentral,
                              to characteristic: CBMMutableCharacteristic) -> Bool {
        dispatchPrecondition(condition: .onQueue(mutex))
        return characteristic.subscribedCentrals?.contains(where: {
            $0.identifier == central.identifier
        }) ?? false
    }

    /// Must be called on the ``mutex``.
    private func central(for spec: CBMCentralSpec) -> CBMCentralMock {
        dispatchPrecondition(condition: .onQueue(mutex))
        if let central = centrals[spec.identifier] {
            return central
        }
        let central = CBMCentralMock(basedOn: spec)
        centrals[spec.identifier] = central
        return central
    }

    private func central(didDisconnect spec: CBMCentralSpec) {
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            let disconnected: (central: CBMCentralMock,
                               characteristics: [CBMMutableCharacteristic])? = self.mutex.sync {
                guard let central = self.centrals.removeValue(forKey: spec.identifier) else {
                    return nil
                }
                self.pendingRequests.removeAll { $0.central.identifier == spec.identifier }
                let characteristics = self.services
                    .flatMap { $0.characteristics ?? [] }
                    .compactMap { $0 as? CBMMutableCharacteristic }
                    .filter { self.isSubscribed(central, to: $0) }
                characteristics.forEach { characteristic in
                    characteristic.subscribedCentrals?.removeAll {
                        $0.identifier == central.identifier
                    }
                }
                return (central, characteristics)
            }
            guard let result = disconnected, self.state == .poweredOn else {
                return
            }
            result.characteristics.forEach { characteristic in
                self.delegate?.peripheralManager(self,
                                                 central: result.central,
                                                 didUnsubscribeFrom: characteristic)
            }
        }
    }
}
