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

/// A configurable delegate of a peripheral manager.
private final class TestDelegate: NSObject, CBMPeripheralManagerDelegate {
    var onStartAdvertising: ((Error?) -> Void)?
    var onRead: ((CBMPeripheralManager, CBMATTRequest) -> Void)?
    var onWrite: ((CBMPeripheralManager, [CBMATTRequest]) -> Void)?
    var onReady: (() -> Void)?

    func peripheralManagerDidUpdateState(_ peripheral: CBMPeripheralManager) {}

    func peripheralManagerDidStartAdvertising(_ peripheral: CBMPeripheralManager, error: Error?) {
        onStartAdvertising?(error)
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager, didReceiveRead request: CBMATTRequest) {
        onRead?(peripheral, request)
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager, didReceiveWrite requests: [CBMATTRequest]) {
        onWrite?(peripheral, requests)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBMPeripheralManager) {
        onReady?()
    }
}

/// A collector of notifications received by a mock central.
private final class TestCentralDelegate: CBMCentralSpecDelegate {
    var updates: [Data] = []
    var onUpdate: (() -> Void)?

    func central(_ central: CBMCentralSpec, didReceiveUpdate value: Data,
                 for characteristic: CBMMutableCharacteristic) {
        updates.append(value)
        onUpdate?()
    }
}

/// Tests of the peripheral manager and the mock central, checking the behavior
/// of the native `CBPeripheralManager`.
class PeripheralManagerBehaviorTest: XCTestCase {
    private let serviceUUID = CBMUUID(string: "1111")
    private let readUUID = CBMUUID(string: "AA01")
    private let writeUUID = CBMUUID(string: "AA02")
    private let notifyUUID = CBMUUID(string: "AA03")
    private let cachedUUID = CBMUUID(string: "AA04")

    private var delegate: TestDelegate!
    private var centralDelegate: TestCentralDelegate!
    private var manager: CBMPeripheralManagerMock!
    private var central: CBMCentralSpec!
    private var readCharacteristic: CBMMutableCharacteristic!
    private var writeCharacteristic: CBMMutableCharacteristic!
    private var notifyCharacteristic: CBMMutableCharacteristic!
    private var cachedCharacteristic: CBMMutableCharacteristic!

    override func setUpWithError() throws {
        CBMCentralManagerMock.simulateInitialState(.poweredOn)
        delegate = TestDelegate()
        centralDelegate = TestCentralDelegate()
        central = CBMCentralSpec(maximumUpdateValueLength: 20,
                                 connectionInterval: 0.01,
                                 delegate: centralDelegate)

        readCharacteristic = CBMMutableCharacteristic(
            type: readUUID, properties: [.read], value: nil, permissions: [.readable])
        writeCharacteristic = CBMMutableCharacteristic(
            type: writeUUID, properties: [.write, .writeWithoutResponse], value: nil,
            permissions: [.writeable])
        notifyCharacteristic = CBMMutableCharacteristic(
            type: notifyUUID, properties: [.notify, .read], value: nil, permissions: [.readable])
        cachedCharacteristic = CBMMutableCharacteristic(
            type: cachedUUID, properties: [.read], value: Data([0, 1, 2, 3, 4, 5]),
            permissions: [.readable])
        let service = CBMMutableService(type: serviceUUID, primary: true)
        service.characteristics = [readCharacteristic, writeCharacteristic,
                                   notifyCharacteristic, cachedCharacteristic]

        manager = CBMPeripheralManagerMock(delegate: delegate, queue: nil)
        let added = expectation(description: "Service added")
        let proxy = ServiceAddedDelegate(added)
        manager.delegate = proxy
        waitUntil { self.manager.state == .poweredOn }
        manager.add(service)
        wait(for: [added], timeout: 1.0)
        manager.delegate = delegate
        withExtendedLifetime(proxy) {}
    }

    override func tearDownWithError() throws {
        CBMCentralManagerMock.tearDownSimulation()
        if #available(iOS 13.0, *) {
            CBMCentralManagerMock.simulateAuthorization(.allowedAlways)
        }
        manager = nil
        central = nil
    }

    // MARK: - Advertising

    func testStartAdvertising() {
        let started = expectation(description: "Started")
        delegate.onStartAdvertising = { error in
            XCTAssertNil(error)
            started.fulfill()
        }
        manager.startAdvertising([CBMAdvertisementDataLocalNameKey: "Name"])
        wait(for: [started], timeout: 1.0)
        XCTAssertTrue(manager.isAdvertising)

        manager.stopAdvertising()
        XCTAssertFalse(manager.isAdvertising)
    }

    func testStartingAdvertisingTwiceReportsError() {
        var results: [Error?] = []
        let finished = expectation(description: "Both reported")
        delegate.onStartAdvertising = { error in
            results.append(error)
            if results.count == 2 { finished.fulfill() }
        }
        manager.startAdvertising([CBMAdvertisementDataLocalNameKey: "Name"])
        manager.startAdvertising([CBMAdvertisementDataLocalNameKey: "Name"])
        wait(for: [finished], timeout: 1.0)

        XCTAssertEqual(results.compactMap { $0 }.count, 1)
        XCTAssertEqual((results.compactMap { $0 }.first as? CBMError)?.code, .alreadyAdvertising)
    }

    // MARK: - Reading and writing

    func testReadOfCachedValueSupportsOffset() throws {
        central.simulateConnection()
        let read = expectation(description: "Read")
        central.simulateReadRequest(for: cachedCharacteristic, offset: 2) { result in
            XCTAssertEqual(try? result.get(), Data([2, 3, 4, 5]))
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    func testReadWithInvalidOffset() throws {
        central.simulateConnection()
        let read = expectation(description: "Read")
        central.simulateReadRequest(for: cachedCharacteristic, offset: 10) { result in
            guard case .failure(let error) = result else { return XCTFail("Should fail") }
            XCTAssertEqual((error as? CBMATTError)?.code, .invalidOffset)
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    func testReadIsRejectedWithoutPermission() throws {
        let writeOnly = CBMMutableCharacteristic(
            type: CBMUUID(string: "AA05"), properties: [.read], value: nil, permissions: [])
        let service = CBMMutableService(type: CBMUUID(string: "2222"), primary: true)
        service.characteristics = [writeOnly]
        manager.add(service)
        central.simulateConnection()

        let read = expectation(description: "Read")
        central.simulateReadRequest(for: writeOnly) { result in
            guard case .failure(let error) = result else { return XCTFail("Should fail") }
            XCTAssertEqual((error as? CBMATTError)?.code, .readNotPermitted)
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    func testReadRequestIsAnsweredByDelegate() throws {
        central.simulateConnection()
        delegate.onRead = { manager, request in
            XCTAssertEqual(request.characteristic.uuid, self.readUUID)
            XCTAssertEqual(request.offset, 0)
            XCTAssertNil(request.value)
            request.value = Data([0x42])
            manager.respond(to: request, withResult: .success)
        }
        let read = expectation(description: "Read")
        central.simulateReadRequest(for: readCharacteristic) { result in
            XCTAssertEqual(try? result.get(), Data([0x42]))
            read.fulfill()
        }
        wait(for: [read], timeout: 1.0)
    }

    func testWriteWithoutResponseIsNotAnswered() throws {
        central.simulateConnection()
        let received = expectation(description: "Write received")
        delegate.onWrite = { _, requests in
            XCTAssertEqual(requests.count, 1)
            XCTAssertEqual(requests.first?.value, Data([0x01]))
            received.fulfill()
        }
        central.simulateWriteRequestWithoutResponse(Data([0x01]), for: writeCharacteristic)
        wait(for: [received], timeout: 1.0)
    }

    func testWriteIsRejectedWithoutPermission() throws {
        central.simulateConnection()
        let written = expectation(description: "Written")
        central.simulateWriteRequest(Data([0x01]), for: readCharacteristic) { result in
            guard case .failure(let error) = result else { return XCTFail("Should fail") }
            XCTAssertEqual((error as? CBMATTError)?.code, .writeNotPermitted)
            written.fulfill()
        }
        wait(for: [written], timeout: 1.0)
    }

    func testRequestsWithoutResponseFailWhenCentralDisconnects() throws {
        central.simulateConnection()
        let requestReceived = expectation(description: "Read received")
        // The delegate never responds.
        delegate.onRead = { _, _ in requestReceived.fulfill() }

        let failed = expectation(description: "Read failed")
        central.simulateReadRequest(for: readCharacteristic) { result in
            guard case .failure = result else { return XCTFail("Should fail") }
            failed.fulfill()
        }
        wait(for: [requestReceived], timeout: 1.0)

        central.simulateDisconnection()
        wait(for: [failed], timeout: 1.0)
    }

    func testPendingWriteFailsWhenAdapterIsPoweredOff() throws {
        central.simulateConnection()
        let requestReceived = expectation(description: "Write received")
        delegate.onWrite = { _, _ in requestReceived.fulfill() }

        let failed = expectation(description: "Write failed")
        central.simulateWriteRequest(Data([0x01]), for: writeCharacteristic) { result in
            guard case .failure = result else { return XCTFail("Should fail") }
            failed.fulfill()
        }
        wait(for: [requestReceived], timeout: 1.0)

        CBMCentralManagerMock.simulatePowerOff()
        wait(for: [failed], timeout: 1.0)
    }

    // MARK: - Notifications

    private func subscribe() {
        central.simulateConnection()
        central.simulateSubscription(to: notifyCharacteristic)
        waitUntil { self.notifyCharacteristic.subscribedCentrals?.count == 1 }
    }

    func testNotificationIsTruncatedToMaximumUpdateValueLength() {
        subscribe()
        let received = expectation(description: "Received")
        centralDelegate.onUpdate = { received.fulfill() }

        XCTAssertTrue(manager.updateValue(Data(repeating: 0xAB, count: 50),
                                          for: notifyCharacteristic,
                                          onSubscribedCentrals: nil))
        wait(for: [received], timeout: 1.0)
        XCTAssertEqual(centralDelegate.updates.first?.count, 20)
    }

    func testNotificationCanBeSentToSelectedCentrals() {
        subscribe()
        let other = CBMCentralSpec(connectionInterval: 0.01)
        other.simulateConnection()
        other.simulateSubscription(to: notifyCharacteristic)
        waitUntil { self.notifyCharacteristic.subscribedCentrals?.count == 2 }
        let otherCentral = notifyCharacteristic.subscribedCentrals!
            .first { $0.identifier == other.identifier }!

        XCTAssertTrue(manager.updateValue(Data([0x01]), for: notifyCharacteristic,
                                          onSubscribedCentrals: [otherCentral]))
        let inverted = expectation(description: "Not received")
        inverted.isInverted = true
        centralDelegate.onUpdate = { inverted.fulfill() }
        wait(for: [inverted], timeout: 0.3)
        XCTAssertTrue(centralDelegate.updates.isEmpty)
    }

    func testFullTransmitQueueIsReportedAndReadyCallbackFollows() {
        subscribe()
        var accepted = 0
        for _ in 0..<100 {
            guard manager.updateValue(Data([0x01]), for: notifyCharacteristic,
                                      onSubscribedCentrals: nil) else {
                break
            }
            accepted += 1
        }
        XCTAssertGreaterThan(accepted, 0)
        XCTAssertLessThan(accepted, 100, "The transmit queue should have filled up")

        let ready = expectation(description: "Ready to update subscribers")
        delegate.onReady = { ready.fulfill() }
        wait(for: [ready], timeout: 2.0)
        XCTAssertTrue(manager.updateValue(Data([0x02]), for: notifyCharacteristic,
                                          onSubscribedCentrals: nil))
    }

    func testRemovingServiceUnsubscribesCentrals() {
        subscribe()
        manager.removeAllServices()
        XCTAssertNil(notifyCharacteristic.subscribedCentrals)
    }

    // MARK: - Adapter and authorization

    func testPowerOffDisconnectsCentralsAndStopsAdvertising() {
        let started = expectation(description: "Started")
        delegate.onStartAdvertising = { _ in started.fulfill() }
        manager.startAdvertising([CBMAdvertisementDataLocalNameKey: "Name"])
        wait(for: [started], timeout: 1.0)
        central.simulateConnection()
        XCTAssertNotNil(central.simulateScan())

        CBMCentralManagerMock.simulatePowerOff()
        waitUntil { !self.manager.isAdvertising }

        XCTAssertFalse(central.isConnected)
        XCTAssertNil(central.simulateScan())
    }

    func testLosingAuthorizationDisconnectsCentrals() throws {
        guard #available(iOS 13.0, *) else { throw XCTSkip("Requires iOS 13") }
        central.simulateConnection()

        CBMCentralManagerMock.simulateAuthorization(.denied)
        waitUntil { self.manager.state == .unauthorized }

        XCTAssertFalse(central.isConnected)
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 1.0, _ condition: @escaping () -> Bool) {
        let done = expectation(description: "Condition met")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                done.fulfill()
            }
        }
        wait(for: [done], timeout: timeout)
        timer.invalidate()
    }
}

private final class ServiceAddedDelegate: NSObject, CBMPeripheralManagerDelegate {
    let expectation: XCTestExpectation
    init(_ expectation: XCTestExpectation) { self.expectation = expectation }

    func peripheralManagerDidUpdateState(_ peripheral: CBMPeripheralManager) {}

    func peripheralManager(_ peripheral: CBMPeripheralManager, didAdd service: CBMService, error: Error?) {
        XCTAssertNil(error)
        expectation.fulfill()
    }
}
