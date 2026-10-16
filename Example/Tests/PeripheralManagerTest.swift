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
@testable import CoreBluetoothMock

/// A Heart Rate sensor implemented with the peripheral role.
///
/// This is the kind of class a test would normally exercise: it owns a
/// ``CBMPeripheralManager``, publishes a GATT database and streams
/// measurements to whoever subscribes. It has no knowledge of being mocked.
private class HeartRateSensor: NSObject, CBMPeripheralManagerDelegate {

    /// Heart Rate Measurement, streamed to subscribers.
    let measurement = CBMMutableCharacteristic(
        type: .heartRateMeasurement,
        properties: [.notify],
        value: nil,
        permissions: []
    )
    /// Body Sensor Location, read on demand and answered by this class.
    let sensorLocation = CBMMutableCharacteristic(
        type: .bodySensorLocation,
        properties: [.read],
        value: nil,
        permissions: [.readable]
    )
    /// Heart Rate Control Point, written by the client to reset energy expended.
    let controlPoint = CBMMutableCharacteristic(
        type: .heartRateControlPoint,
        properties: [.write],
        value: nil,
        permissions: [.writeable]
    )
    /// Manufacturer Name, a cached value the system answers without asking us.
    let manufacturer = CBMMutableCharacteristic(
        type: .manufacturerName,
        properties: [.read],
        value: "Nordic Semiconductor".data(using: .utf8),
        permissions: [.readable]
    )

    private(set) lazy var service: CBMMutableService = {
        let service = CBMMutableService(type: .heartRate, primary: true)
        service.characteristics = [measurement, sensorLocation, controlPoint, manufacturer]
        return service
    }()

    private var manager: CBMPeripheralManager!

    /// Where the sensor is worn, reported through Body Sensor Location.
    var location: UInt8 = 0x02 // Wrist
    /// Accumulated energy expended, reset by the control point.
    private(set) var energyExpended: UInt16 = 500
    /// Number of clients currently subscribed to measurements.
    private(set) var subscriberCount: Int = 0

    /// Starts the sensor.
    /// - Parameter forceMock: Pass `true` to use the mock implementation on a
    ///                        physical device. On a simulator the mock is used
    ///                        regardless.
    func start(forceMock: Bool = false) {
        manager = CBMPeripheralManagerFactory.instance(delegate: self,
                                                       queue: .main,
                                                       forceMock: forceMock)
    }

    /// Sends a measurement to every subscribed client.
    /// - Parameter bpm: Beats per minute.
    /// - Returns: `false` if the transmit queue is full.
    @discardableResult
    func send(bpm: UInt8) -> Bool {
        // Flags byte: 8-bit value, no contact, energy expended present.
        let value = Data([0b0000_1000, bpm])
            + withUnsafeBytes(of: energyExpended.littleEndian) { Data($0) }
        return manager.updateValue(value, for: measurement, onSubscribedCentrals: nil)
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBMPeripheralManager) {
        guard peripheral.state == .poweredOn else {
            subscriberCount = 0
            return
        }
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didAdd service: CBMService,
                           error: Error?) {
        guard error == nil else { return }
        peripheral.startAdvertising([
            CBMAdvertisementDataLocalNameKey: "Nordic HRM",
            CBMAdvertisementDataServiceUUIDsKey: [CBMUUID.heartRate]
        ])
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didSubscribeTo characteristic: CBMCharacteristic) {
        subscriberCount += 1
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didUnsubscribeFrom characteristic: CBMCharacteristic) {
        subscriberCount -= 1
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveRead request: CBMATTRequest) {
        guard request.characteristic.uuid == .bodySensorLocation else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        request.value = Data([location])
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveWrite requests: [CBMATTRequest]) {
        // Requests must be treated as one atomic unit: validate them all before
        // applying any, and respond only to the first one.
        guard let first = requests.first else { return }
        for request in requests {
            guard request.characteristic.uuid == .heartRateControlPoint else {
                peripheral.respond(to: first, withResult: .attributeNotFound)
                return
            }
            guard request.value == Data([0x01]) else {
                peripheral.respond(to: first, withResult: .invalidAttributeValueLength)
                return
            }
        }
        energyExpended = 0
        peripheral.respond(to: first, withResult: .success)
    }
}

/// Collects notifications sent to a mock central.
private class HeartRateClient: CBMCentralSpecDelegate {
    var onMeasurement: ((Data) -> ())?

    func central(_ central: CBMCentralSpec,
                 didReceiveUpdate value: Data,
                 for characteristic: CBMMutableCharacteristic) {
        onMeasurement?(value)
    }
}

/// Demonstrates driving a ``CBMPeripheralManagerMock`` from a ``CBMCentralSpec``.
///
/// The sensor plays the local peripheral role. The central spec plays a remote
/// device: it scans, connects, subscribes, reads and writes, and receives
/// notifications.
class PeripheralManagerTest: XCTestCase {

    private var sensor: HeartRateSensor!
    private var client: HeartRateClient!
    private var central: CBMCentralSpec!

    override func setUpWithError() throws {
        // The Bluetooth adapter is shared with the central role.
        CBMCentralManagerMock.simulateInitialState(.poweredOn)

        client = HeartRateClient()
        central = CBMCentralSpec(maximumUpdateValueLength: 20,
                                 connectionInterval: 0.01,
                                 delegate: client)

        sensor = HeartRateSensor()
        sensor.start(forceMock: true)

        // The manager reports its state asynchronously; the service is added and
        // advertising starts from that callback.
        wait(until: { self.central.simulateScan() != nil },
             timeout: 1.0, description: "Advertising started")
    }

    override func tearDownWithError() throws {
        CBMCentralManagerMock.tearDownSimulation()
        sensor = nil
        client = nil
        central = nil
    }

    /// The central scans and finds the advertisement the sensor started.
    func testScanning() {
        let advertisement = try? XCTUnwrap(central.simulateScan(withServices: [.heartRate]))
        XCTAssertEqual(advertisement?[CBMAdvertisementDataLocalNameKey] as? String, "Nordic HRM")
        XCTAssertEqual(advertisement?[CBMAdvertisementDataServiceUUIDsKey] as? [CBMUUID], [.heartRate])

        // A filter that does not match the advertised services returns nothing.
        XCTAssertNil(central.simulateScan(withServices: [.batteryService]))
    }

    /// Subscribing streams measurements to the client until it unsubscribes.
    func testNotifications() {
        central.simulateConnection()
        XCTAssertTrue(central.isConnected)

        central.simulateSubscription(to: sensor.measurement)
        wait(until: { self.sensor.subscriberCount == 1 }, description: "Subscribed")
        XCTAssertEqual(sensor.measurement.subscribedCentrals?.count, 1)

        let received = XCTestExpectation(description: "Measurement received")
        client.onMeasurement = { value in
            XCTAssertEqual(value[1], 72)
            received.fulfill()
        }
        XCTAssertTrue(sensor.send(bpm: 72))
        wait(for: [received], timeout: 1.0)

        central.simulateUnsubscription(from: sensor.measurement)
        wait(until: { self.sensor.subscriberCount == 0 }, description: "Unsubscribed")

        // With no subscribers the update is dropped, but sending still succeeds.
        client.onMeasurement = { _ in XCTFail("Unsubscribed client was notified") }
        XCTAssertTrue(sensor.send(bpm: 80))
        wait(0.1)
    }

    /// A read of a characteristic without a cached value reaches the delegate.
    func testReadRequest() {
        central.simulateConnection()
        sensor.location = 0x01 // Chest

        let read = XCTestExpectation(description: "Location read")
        central.simulateReadRequest(for: sensor.sensorLocation) { result in
            XCTAssertEqual(try? result.get(), Data([0x01]))
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    /// A characteristic created with a value is answered without the delegate.
    func testReadOfCachedValue() {
        central.simulateConnection()

        let read = XCTestExpectation(description: "Manufacturer read")
        central.simulateReadRequest(for: sensor.manufacturer) { result in
            XCTAssertEqual(try? result.get(), "Nordic Semiconductor".data(using: .utf8))
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    /// A write request reaches the delegate, which accepts or rejects it.
    func testWriteRequest() {
        central.simulateConnection()
        XCTAssertEqual(sensor.energyExpended, 500)

        let accepted = XCTestExpectation(description: "Control point accepted")
        central.simulateWriteRequest(Data([0x01]), for: sensor.controlPoint) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            accepted.fulfill()
        }
        wait(for: [accepted], timeout: 1.0)
        XCTAssertEqual(sensor.energyExpended, 0)

        let rejected = XCTestExpectation(description: "Bad opcode rejected")
        central.simulateWriteRequest(Data([0xFF]), for: sensor.controlPoint) { result in
            guard case .failure(let error) = result else {
                return XCTFail("Write should have been rejected")
            }
            XCTAssertEqual((error as? CBMATTError)?.code, .invalidAttributeValueLength)
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: 1.0)

        // A characteristic without the .write property is rejected before the
        // delegate is consulted.
        let notPermitted = XCTestExpectation(description: "Write not permitted")
        central.simulateWriteRequest(Data([0x01]), for: sensor.measurement) { result in
            guard case .failure(let error) = result else {
                return XCTFail("Write should have been rejected")
            }
            XCTAssertEqual((error as? CBMATTError)?.code, .writeNotPermitted)
            notPermitted.fulfill()
        }
        wait(for: [notPermitted], timeout: 1.0)
    }

    /// Disconnecting unsubscribes the central from everything it was subscribed to.
    func testDisconnection() {
        central.simulateConnection()
        central.simulateSubscription(to: sensor.measurement)
        wait(until: { self.sensor.subscriberCount == 1 }, description: "Subscribed")

        central.simulateDisconnection()
        XCTAssertFalse(central.isConnected)
        wait(until: { self.sensor.subscriberCount == 0 }, description: "Unsubscribed")
    }

    /// Powering the adapter off resets the peripheral manager, exactly as it
    /// resets central managers.
    func testPowerOff() {
        central.simulateConnection()
        CBMCentralManagerMock.simulatePowerOff()

        XCTAssertFalse(central.isConnected)
        wait(until: { self.central.simulateScan() == nil }, description: "Advertising stopped")

        // The service is gone, so requests no longer resolve to a manager.
        let failed = XCTestExpectation(description: "Read failed")
        central.simulateReadRequest(for: sensor.sensorLocation) { result in
            guard case .failure(let error) = result else {
                return XCTFail("Read should have failed")
            }
            XCTAssertEqual((error as? CBMATTError)?.code, .attributeNotFound)
            failed.fulfill()
        }
        wait(for: [failed], timeout: 1.0)
    }
}

private extension XCTestCase {

    /// Waits until the given condition is met, polling on the main run loop.
    func wait(until condition: @escaping () -> Bool,
              timeout: TimeInterval = 1.0,
              description: String) {
        let expectation = XCTestExpectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }

    /// Lets the run loop spin for the given time.
    func wait(_ interval: TimeInterval) {
        let expectation = XCTestExpectation(description: "Delay")
        expectation.isInverted = true
        wait(for: [expectation], timeout: interval)
    }
}

private extension CBMUUID {
    static let heartRate            = CBMUUID(string: "180D")
    static let batteryService       = CBMUUID(string: "180F")
    static let heartRateMeasurement = CBMUUID(string: "2A37")
    static let bodySensorLocation   = CBMUUID(string: "2A38")
    static let heartRateControlPoint = CBMUUID(string: "2A39")
    static let manufacturerName     = CBMUUID(string: "2A29")
}
