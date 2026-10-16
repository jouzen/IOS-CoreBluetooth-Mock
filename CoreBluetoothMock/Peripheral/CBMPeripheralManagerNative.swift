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

#if os(iOS) || os(macOS)
import CoreBluetooth

public class CBMPeripheralManagerNative: CBMPeripheralManager {
    private var observation: NSKeyValueObservation?
    @objc dynamic private var manager: CBPeripheralManager!
    private var wrapper: CBPeripheralManagerDelegate!
    private var centrals = CBMDictionary<UUID, CBMCentralNative>()
    
    private var services: [(mock: CBMMutableService, native: CBMutableService)] = []
    private var characteristics: [(mock: CBMMutableCharacteristic, native: CBMutableCharacteristic)] = []
    
    public override var state: CBMManagerState {
        CBMManagerState(rawValue: manager.state.rawValue) ?? .unknown
    }
    
    public override var isAdvertising: Bool {
        get {
            manager.isAdvertising
        }
        set {
            
        }
    }
    
    @available(iOS, introduced: 13.0, deprecated: 13.1)
    @available(macOS, introduced: 10.15)
    public override var authorization: CBMManagerAuthorization {
        return manager.authorization
    }
    
    @available(iOS 13.1, macOS 10.15, *)
    public override class var authorization: CBMManagerAuthorization {
        return CBPeripheralManager.authorization
    }
    
    public init(delegate: CBMPeripheralManagerDelegate? = nil,
                queue: DispatchQueue? = nil,
                options: [String : Any]? = nil) {
        super.init(true)
        
        let restoration = options?[CBMPeripheralManagerOptionRestoreIdentifierKey] != nil
        
        self.wrapper = restoration ?
            CBMPeripheralManagerDelegateWrapperWithRestoration(self) :
            CBMPeripheralManagerDelegateWrapper(self)
        
        self.manager = CBPeripheralManager(delegate: wrapper, queue: queue, options: options)
        self.delegate = delegate
        self.addManagerObserver()
    }
    
    public override func startAdvertising(_ advertisementData: [String : Any]?) {
        manager.startAdvertising(advertisementData)
    }
    
    public override func stopAdvertising() {
        manager.stopAdvertising()
    }
    
    public override func setDesiredConnectionLatency(_ latency: CBMPeripheralManagerConnectionLatency,
                                                     for central: CBMCentral) {
        guard let central = central as? CBMCentralNative
        else { return }
        
        manager.setDesiredConnectionLatency(latency, for: central.central)
    }
    
    public override func add(_ service: CBMMutableService) {
        manager.add(native(of: service))
    }
    
    public override func remove(_ service: CBMMutableService) {
        guard let index = services.firstIndex(where: { $0.mock === service })
                else { return }
        
        let native = services[index].native
        manager.remove(native)
        services.remove(at: index)
        characteristics.removeAll { pair in
            native.characteristics?.contains { $0 === pair.native } ?? false
        }
    }
    
    public override func removeAllServices() {
        manager.removeAllServices()
        services.removeAll()
        characteristics.removeAll()
    }
    
    public override func respond(to request: CBMATTRequest, withResult result: CBMATTError.Code) {
        guard let request = request as? CBMATTRequestNative else {
            return
        }
        manager.respond(to: request.request, withResult: result)
    }
    
    public override func updateValue(_ value: Data,
                                     for characteristic: CBMMutableCharacteristic,
                                     onSubscribedCentrals centrals: [CBMCentral]?) -> Bool {
        guard let native = characteristics.first(where: { $0.mock === characteristic })?.native else {
            NSLog("[CoreBluetoothMock] API MISUSE: Characteristic \(characteristic.uuid) has not been added to \(self)")
            return false
        }
        let nativeCentrals = centrals?.compactMap { ($0 as? CBMCentralNative)?.central }
        return manager.updateValue(value, for: native, onSubscribedCentrals: nativeCentrals)
    }
    
    @available(iOS 11.0, *)
    public override func publishL2CAPChannel(withEncryption encryptionRequired: Bool) {
        manager.publishL2CAPChannel(withEncryption: encryptionRequired)
    }
    
    @available(iOS 11.0, *)
    public override func unpublishL2CAPChannel(_ PSM: CBML2CAPPSM) {
        manager.unpublishL2CAPChannel(PSM)
    }
}
  
extension CBMPeripheralManagerNative {
    private func addManagerObserver() {
      observation = observe(\.manager?.isAdvertising, options: [.old, .new]) { _, change in
        change.newValue?.flatMap { [weak self] new in
          self?.isAdvertising = new
        }
      }
    }

    private func native(of service: CBMMutableService) -> CBMutableService {
        if let existing = services.first(where: { $0.mock === service }) {
            return existing.native
        }
        let native = CBMutableService(type: service.uuid, primary: service.isPrimary)
        native.characteristics = service.characteristics?.compactMap { characteristic in
            guard let mutable = characteristic as? CBMMutableCharacteristic else {
                NSLog("[CoreBluetoothMock] API MISUSE: Characteristic \(characteristic.uuid) is not a CBMMutableCharacteristic and will be skipped")
                return nil
            }
            return self.native(of: mutable)
        }
        native.includedServices = service.includedServices?.compactMap { included in
            services.first { $0.mock === included }?.native
        }
        services.append((service, native))
        return native
    }

    private func native(of characteristic: CBMMutableCharacteristic) -> CBMutableCharacteristic {
        if let existing = characteristics.first(where: { $0.mock === characteristic }) {
            return existing.native
        }
        let native = CBMutableCharacteristic(type: characteristic.uuid,
                                             properties: characteristic.properties,
                                             value: characteristic.value,
                                             permissions: characteristic.permissions)
        native.descriptors = characteristic.descriptors?.map {
            CBMutableDescriptor(type: $0.uuid, value: $0.value)
        }
        characteristics.append((characteristic, native))
        return native
    }

    private func mock(of service: CBService) -> CBMMutableService {
        if let existing = services.first(where: { $0.native === service }) {
            return existing.mock
        }
        let mock = CBMMutableService(type: service.uuid, primary: service.isPrimary)
        mock.characteristics = service.characteristics?.map { self.mock(of: $0) }
        mock.includedServices = service.includedServices?.map { self.mock(of: $0) }
        if let native = service as? CBMutableService {
            services.append((mock, native))
        }
        return mock
    }

    private func mock(of characteristic: CBCharacteristic) -> CBMMutableCharacteristic {
        if let existing = characteristics.first(where: { $0.native === characteristic }) {
            return existing.mock
        }
        let mutable = characteristic as? CBMutableCharacteristic
        let mock = CBMMutableCharacteristic(type: characteristic.uuid,
                                            properties: characteristic.properties,
                                            value: characteristic.value,
                                            permissions: mutable?.permissions ?? [])
        mock.descriptors = characteristic.descriptors?.map {
            CBMMutableDescriptor(type: $0.uuid, value: $0.value)
        }
        if let mutable = mutable {
            characteristics.append((mock, mutable))
        }
        return mock
    }
}

extension CBMPeripheralManagerNative {
  private class CBMPeripheralManagerDelegateWrapper: NSObject, CBPeripheralManagerDelegate {
    fileprivate weak var manager: CBMPeripheralManagerNative!
    
    init(_ manager: CBMPeripheralManagerNative) {
      self.manager = manager
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
      manager.delegate?.peripheralManagerDidUpdateState(manager)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager,
                                              error: Error?) {
      manager.delegate?.peripheralManagerDidStartAdvertising(manager, error: error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didAdd service: CBService,
                           error: Error?) {
      manager.delegate?.peripheralManager(manager,
                                          didAdd: manager.mock(of: service),
                                          error: error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
      let mockCentral = getCentral(central)
      let mockCharacteristic = manager.mock(of: characteristic)
      var subscribedCentrals = mockCharacteristic.subscribedCentrals ?? []
        
      if !subscribedCentrals.contains(where: { $0.identifier == mockCentral.identifier }) {
        subscribedCentrals.append(mockCentral)
      }
      mockCharacteristic.subscribedCentrals = subscribedCentrals
        
      manager.delegate?.peripheralManager(manager,
                                          central: mockCentral,
                                          didSubscribeTo: mockCharacteristic)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
      let mockCentral = getCentral(central)
      let mockCharacteristic = manager.mock(of: characteristic)
      mockCharacteristic.subscribedCentrals?.removeAll {
        $0.identifier == mockCentral.identifier
      }
      manager.delegate?.peripheralManager(manager,
                                          central: mockCentral,
                                          didUnsubscribeFrom: mockCharacteristic)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
      manager.delegate?.peripheralManager(manager,
                                          didReceiveRead: wrap(request))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveWrite requests: [CBATTRequest]) {
      manager.delegate?.peripheralManager(manager,
                                          didReceiveWrite: requests.map { wrap($0) })
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
      manager.delegate?.peripheralManagerIsReady(toUpdateSubscribers: manager)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didPublishL2CAPChannel PSM: CBL2CAPPSM,
                           error: Error?) {
      manager.delegate?.peripheralManager(manager,
                                          didPublishL2CAPChannel: PSM,
                                          error: error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didUnpublishL2CAPChannel PSM: CBL2CAPPSM,
                           error: Error?) {
      manager.delegate?.peripheralManager(manager,
                                          didUnpublishL2CAPChannel: PSM,
                                          error: error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didOpen channel: CBL2CAPChannel?,
                           error: Error?) {
      manager.delegate?.peripheralManager(manager,
                                          didOpen: channel,
                                          error: error)
    }
    
    private func wrap(_ request: CBATTRequest) -> CBMATTRequestNative {
      return CBMATTRequestNative(request,
                                 central: getCentral(request.central),
                                 characteristic: manager.mock(of: request.characteristic))
    }
    
    private func getCentral(_ central: CBCentral) -> CBMCentralNative {
      guard
        let cachedCentral = manager.centrals[central.identifier],
        cachedCentral.central === central
      else {
        return newCentral(central)
      }
      return cachedCentral
    }
    
    private func newCentral(_ central: CBCentral) -> CBMCentralNative {
      let c = CBMCentralNative(central)
      manager.centrals[central.identifier] = c
      return c
    }
  }
  
  // peripheralManager:willRestoreState: method is moved to a separate class below because otherwise a warning
  // is generated when setting delegate to the CBPeripheralManager when restoration was not enabled:
  // ----
  // API MISUSE: <CBPeripheralManager: ...> has no restore identifier but the
  // delegate implements the peripheralManager:willRestoreState: method.
  // Restoring will not be supported
  private class CBMPeripheralManagerDelegateWrapperWithRestoration: CBMPeripheralManagerDelegateWrapper {
    override init(_ manager: CBMPeripheralManagerNative) {
      super.init(manager)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager,
                           willRestoreState dict: [String : Any]) {
      var state = dict
      
      if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
        state[CBMPeripheralManagerRestoredStateServicesKey] = services.map {
          manager.mock(of: $0)
        }
      }
      
      manager.delegate?.peripheralManager(manager, willRestoreState: state)
    }
  }
}
#endif
