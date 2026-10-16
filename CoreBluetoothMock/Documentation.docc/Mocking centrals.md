# Mocking Bluetooth LE Centrals

How to test an app that acts as a Bluetooth LE peripheral.

## Overview

The ``CBMPeripheralManagerFactory`` provides two implementations of ``CBMPeripheralManager``:
* ``CBMPeripheralManagerNative``
* ``CBMPeripheralManagerMock``

The native implementation proxies all requests to the **CoreBluetooth** framework.

When the code runs on a simulator (or the `forceMock` parameter was set) a mock manager
is created. Instead of physical devices, it interacts with mock centrals, defined using
``CBMCentralSpec``. The mock central plays the remote device: it scans, connects, subscribes,
reads and writes, and receives notifications.

The Bluetooth adapter is shared with the central role. Use
``CBMCentralManagerMock/simulateInitialState(_:)``, ``CBMCentralManagerMock/simulatePowerOn()``,
``CBMCentralManagerMock/simulatePowerOff()`` and
``CBMCentralManagerMock/simulateAuthorization(_:)`` to control it, and
``CBMCentralManagerMock/tearDownSimulation()`` to reset the simulation between tests.

### Creating the peripheral manager

The code under test does not need to know it is mocked:

```swift
let manager = CBMPeripheralManagerFactory.instance(delegate: self, queue: nil)
```

Services are published using ``CBMMutableService``, ``CBMMutableCharacteristic`` and
``CBMMutableDescriptor``, exactly as with the native API.

> Important: All characteristics must be ``CBMMutableCharacteristic`` objects.
  A characteristic created with a value is cached and must be read-only; requests to read it are
  answered automatically, without calling the delegate.

### Defining a mock central

```swift
let central = CBMCentralSpec(maximumUpdateValueLength: 20,
                             connectionInterval: 0.045,
                             delegate: self)
```

The delegate (``CBMCentralSpecDelegate``) receives notifications and indications sent using
``CBMPeripheralManager/updateValue(_:for:onSubscribedCentrals:)``. The value is truncated
to `maximumUpdateValueLength`, and delivered a connection interval later.

### Simulating a central

```swift
// Scan for the advertising app. Returns the advertisement data, or nil.
let advertisement = central.simulateScan(withServices: [heartRateService])

// Connect and discover the published characteristics.
central.simulateConnection()
let characteristics = central.simulateCharacteristicDiscovery(forService: heartRateService)

// Subscribe to notifications.
central.simulateSubscription(to: measurement)

// Read, write.
central.simulateReadRequest(for: location) { result in ... }
central.simulateWriteRequest(Data([0x01]), for: controlPoint) { result in ... }
central.simulateWriteRequestWithoutResponse(Data([0x01]), for: controlPoint)

central.simulateDisconnection()
```

Requests reach the peripheral manager's delegate a connection interval later.
The delegate has to respond using ``CBMPeripheralManager/respond(to:withResult:)``. The completion
handler of the simulated request is called with the result, or with an error if the central
disconnects or the adapter is turned off before the app responded.

### Behavior matching the native API

* The manager reports ``CBMManagerState/unknown`` until the delegate is called with the
  initial state, and is reset (advertising stops, services are removed, centrals disconnect)
  when the adapter is turned off.
* Calling ``CBMPeripheralManager/startAdvertising(_:)`` while advertising reports
  `alreadyAdvertising` to the delegate.
* Notifications are sent through a transmit queue of limited size. When
  ``CBMPeripheralManager/updateValue(_:for:onSubscribedCentrals:)`` returns `false`, wait for
  ``CBMPeripheralManagerDelegate/peripheralManagerIsReady(toUpdateSubscribers:)``.
* Read and write requests are checked against the characteristic's properties and permissions
  before the delegate is called.

### Limitations

* Only ``CBMAdvertisementDataLocalNameKey`` and ``CBMAdvertisementDataServiceUUIDsKey`` are
  supported in advertisement data. Other keys are ignored.
* Prepared (queued) writes are not simulated: the delegate always receives a single write request.
* L2CAP channels are not implemented.
