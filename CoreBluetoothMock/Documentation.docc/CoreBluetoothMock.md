# ``CoreBluetoothMock``

Test **CoreBluetooth** features in your app using mocks.

## Overview

The **CoreBluetoothMock** library provides an intuitive API for mocking physical 
Bluetooth LE devices using an implementation in Swift. This allows:
* Testing Bluetooth LE connectivity on a simulator,
* Simulating a Bluetooth LE device during the development phase,
* Reliable method for automating tests and taking screenshots.

The library supports both roles: apps acting as a *central* (``CBMCentralManager``) and as
a *peripheral* (``CBMPeripheralManager``).

## Topics

### How to migrate a project to CoreBluetooth Mock framework

- <doc:Migration-guide>

### How to create mock peripherals

- <doc:Mocking-peripherals>

### How to mock centrals when your app is a peripheral

- <doc:Mocking-centrals>

### How to simulate test events

- <doc:Simulation>

### Known issues

- <doc:KnownIssues>

### Mocking Bluetooth LE Devices

The following objects can be used to create mock implementation of Bluetooth LE
devices. Such mock peripherals will be available using ``CBMCentralManagerMock``.

- ``CBMPeripheralSpec``
- ``CBMPeripheralSpecDelegate``
- ``CBMProximity``
- ``CBMAdvertisementConfig``

### Central Manager

- ``CBMCentralManagerFactory``
- ``CBMCentralManager``
- ``CBMCentralManagerDelegate``
- ``CBMCentralManagerDelegateProxy``
- ``CBMCentralManagerMock``
- ``CBMCentralManagerNative``
- ``CBMManagerState``
- ``CBMManagerAuthorization``

### Mocking Bluetooth LE Centrals

The following objects can be used to create mock implementation of Bluetooth LE
centrals. Such mock centrals interact with ``CBMPeripheralManagerMock``.

- ``CBMCentralSpec``
- ``CBMCentralSpecDelegate``

### Peripheral Manager

- ``CBMPeripheralManagerFactory``
- ``CBMPeripheralManager``
- ``CBMPeripheralManagerDelegate``
- ``CBMPeripheralManagerMock``
- ``CBMPeripheralManagerNative``
- ``CBMCentral``
- ``CBMCentralMock``
- ``CBMCentralNative``
- ``CBMATTRequest``
- ``CBMATTRequestMock``
- ``CBMATTRequestNative``
- ``CBMAttributePermissions``
- ``CBMPeripheralManagerConnectionLatency``

### Published Attributes

- ``CBMMutableService``
- ``CBMMutableCharacteristic``
- ``CBMMutableDescriptor``

### Peripheral Manager Options

Keys used to pass options when initializing a peripheral manager, and when restoring its state.

- ``CBMPeripheralManagerOptionShowPowerAlertKey``
- ``CBMPeripheralManagerOptionRestoreIdentifierKey``
- ``CBMPeripheralManagerRestoredStateServicesKey``
- ``CBMPeripheralManagerRestoredStateAdvertisementDataKey``

### Central Manager Initialization Options

Keys used to pass options when initializing a central manager.

- ``CBMCentralManagerOptionRestoreIdentifierKey``
- ``CBMCentralManagerOptionShowPowerAlertKey``

### Central Manager State Restoration Options

Keys used to pass state restoration options to the central manager initializer.

- ``CBMCentralManagerRestoredStatePeripheralsKey``
- ``CBMCentralManagerRestoredStateScanServicesKey``
- ``CBMCentralManagerRestoredStateScanOptionsKey``

### Peripheral

- ``CBMPeer``
- ``CBMPeripheral``
- ``CBMPeripheralDelegate``
- ``CBMPeripheralDelegateProxy``
- ``CBMPeripheralDelegateProxyWithL2CAPChannel``
- ``CBMPeripheralMock``
- ``CBMPeripheralNative``
- ``CBMPeripheralPreview``
- ``CBMPeripheralState``
- ``CBML2CAPPSM``
- ``CBML2CAPChannel``

### Peripheral Connection Options

Keys used to pass options when connecting to a peripheral.

- ``CBMConnectPeripheralOptionEnableAutoReconnect``
- ``CBMConnectPeripheralOptionNotifyOnConnectionKey``
- ``CBMConnectPeripheralOptionNotifyOnDisconnectionKey``
- ``CBMConnectPeripheralOptionNotifyOnNotificationKey``
- ``CBMConnectPeripheralOptionEnableTransportBridgingKey``
- ``CBMConnectPeripheralOptionRequiresANCS``
- ``CBMConnectPeripheralOptionStartDelayKey``

### Attributes

- ``CBMAttribute``
- ``CBMService``
- ``CBMServiceMock``
- ``CBMCharacteristic``
- ``CBMCharacteristicWriteType``
- ``CBMCharacteristicProperties``
- ``CBMCharacteristicMock``
- ``CBMDescriptor``
- ``CBMDescriptorMock``
- ``CBMClientCharacteristicConfigurationDescriptorMock``
- ``CBMCCCDescriptorMock``

### Scanning options

Keys used to pass options when scanning for peripherals.

- ``CBMCentralManagerScanOptionAllowDuplicatesKey``
- ``CBMCentralManagerScanOptionSolicitedServiceUUIDsKey``

### Advertisement Data Retrieval Keys

Keys used to specify items in a dictionary of peripheral advertisement data.

- ``CBMAdvertisementDataLocalNameKey``
- ``CBMAdvertisementDataManufacturerDataKey``
- ``CBMAdvertisementDataServiceDataKey``
- ``CBMAdvertisementDataServiceUUIDsKey``
- ``CBMAdvertisementDataOverflowServiceUUIDsKey``
- ``CBMAdvertisementDataTxPowerLevelKey``
- ``CBMAdvertisementDataIsConnectable``
- ``CBMAdvertisementDataSolicitedServiceUUIDsKey``

### Other

- ``CBMUUID``
- ``CBMError``
- ``CBMATTError``
