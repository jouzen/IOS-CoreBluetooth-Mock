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

/// A protocol that provides updates for local peripheral state changes.
///
/// The `CBMPeripheralManagerDelegate` protocol defines the methods that a delegate of a
/// ``CBMPeripheralManager`` object must adopt. The optional methods of the protocol allow
/// the delegate to monitor the state of published services, advertising and requests from
/// connected centrals.
///
/// The only required method is ``CBMPeripheralManagerDelegate/peripheralManagerDidUpdateState(_:)``;
/// the peripheral manager calls this when its state updates, thereby indicating the availability
/// of the peripheral manager.
public protocol CBMPeripheralManagerDelegate: AnyObject {

    /// Invoked whenever the peripheral manager's state has been updated.
    ///
    /// Commands should only be issued when the state is ``CBMManagerState/poweredOn``.
    ///
    /// Any other state implies that advertising has stopped, all services have been
    /// removed and all connected centrals have been disconnected.
    /// - Parameter peripheral: The peripheral manager whose state has changed.
    func peripheralManagerDidUpdateState(_ peripheral: CBMPeripheralManager)

    /// For apps that opt-in to state preservation and restoration, this is the
    /// first method invoked when your app is relaunched into the background to
    /// complete some Bluetooth-related task.
    ///
    /// Use this method to synchronize your app's state with the state of the Bluetooth system.
    ///
    /// When mocking is enabled, the returned state is obtained using
    ///
    /// ``CBMPeripheralManagerMock/simulateStateRestoration``.
    /// - Parameters:
    ///   - peripheral: The peripheral manager providing this information.
    ///   - dict: A dictionary containing information about peripheral that was
    ///           preserved by the system at the time the app was terminated.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           willRestoreState dict: [String : Any])

    /// This method returns the result of a ``CBMPeripheralManager/startAdvertising(_:)`` call.
    ///
    /// If advertisement failed, the cause is detailed in the error parameter.
    /// - Parameters:
    ///   - peripheral: The peripheral manager providing this information.
    ///   - error: If an error occurred, the cause of the failure.
    func peripheralManagerDidStartAdvertising(_ peripheral: CBMPeripheralManager,
                                              error: Error?)

    /// This method returns the result of an ``CBMPeripheralManager/add(_:)`` call.
    ///
    /// If the service could not be published to the local database, the cause is
    /// detailed in the error parameter.
    /// - Parameters:
    ///   - peripheral: The peripheral manager providing this information.
    ///   - service: The service that was added to the local database.
    ///   - error: If an error occurred, the cause of the failure.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didAdd service: CBMService,
                           error: Error?)

    /// This method is invoked when a central configures the characteristic to notify
    /// or indicate. It should be used as a cue to start sending updates as the
    /// characteristic value changes.
    /// - Parameters:
    ///   - peripheral: The peripheral manager providing this update.
    ///   - central: The central that issued the command.
    ///   - characteristic: The characteristic on which notifications or indications were enabled.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didSubscribeTo characteristic: CBMCharacteristic)

    /// This method is invoked when a central removes notifications/indications
    /// from the characteristic.
    /// - Parameters:
    ///   - peripheral: The peripheral manager providing this update.
    ///   - central: The central that issued the command.
    ///   - characteristic: The characteristic on which notifications or indications were disabled.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didUnsubscribeFrom characteristic: CBMCharacteristic)

    /// This method is invoked when peripheral receives an ATT request for a characteristic
    /// with a dynamic value.
    ///
    /// For every invocation of this method, ``CBMPeripheralManager/respond(to:withResult:)``
    /// must be called exactly once.
    /// - Parameters:
    ///   - peripheral: The peripheral manager requesting this information.
    ///   - request: A ``CBMATTRequest`` object.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveRead request: CBMATTRequest)

    /// This method is invoked when peripheral receives an ATT request or command for
    /// one or more characteristics with a dynamic value.
    ///
    /// For every invocation of this method, ``CBMPeripheralManager/respond(to:withResult:)``
    /// should be called exactly once. If requests contains multiple requests, they must be
    /// treated as an atomic unit. If the execution of one of the requests would cause a failure,
    /// the request and error reason should be provided to `respond(to:withResult:)` and none
    /// of the requests should be executed.
    /// - Parameters:
    ///   - peripheral: The peripheral manager requesting this information.
    ///   - requests: A list of one or more ``CBMATTRequest`` objects.
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveWrite requests: [CBMATTRequest])

    /// This method is invoked after a failed call to
    /// ``CBMPeripheralManager/updateValue(_:for:onSubscribedCentrals:)``,
    /// when peripheral is again ready to send characteristic value updates.
    /// - Parameter peripheral: The peripheral manager providing this update.
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBMPeripheralManager)

    /// This method is the response to a ``CBMPeripheralManager/publishL2CAPChannel(withEncryption:)``
    /// call. The PSM will contain the PSM that was assigned for the published channel.
    /// - Parameters:
    ///   - peripheral: The peripheral manager requesting this information.
    ///   - PSM: The PSM of the channel that was published.
    ///   - error: If an error occurred, the cause of the failure.
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didPublishL2CAPChannel PSM: CBML2CAPPSM,
                           error: Error?)

    /// This method is the response to a ``CBMPeripheralManager/unpublishL2CAPChannel(_:)`` call.
    /// - Parameters:
    ///   - peripheral: The peripheral manager requesting this information.
    ///   - PSM: The PSM of the channel that was unpublished.
    ///   - error: If an error occurred, the cause of the failure.
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didUnpublishL2CAPChannel PSM: CBML2CAPPSM,
                           error: Error?)

    /// This method returns the result of establishing an incoming L2CAP channel,
    /// following publishing a channel using
    /// ``CBMPeripheralManager/publishL2CAPChannel(withEncryption:)`` call.
    /// - Parameters:
    ///   - peripheral: The peripheral manager requesting this information.
    ///   - channel: A ``CBML2CAPChannel`` object.
    ///   - error: If an error occurred, the cause of the failure.
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didOpen channel: CBML2CAPChannel?,
                           error: Error?)
}

public extension CBMPeripheralManagerDelegate {

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           willRestoreState dict: [String : Any]) {
        // optional method
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBMPeripheralManager,
                                              error: Error?) {
        // optional method
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didAdd service: CBMService,
                           error: Error?) {
        // optional method
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didSubscribeTo characteristic: CBMCharacteristic) {
        // optional method
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           central: CBMCentral,
                           didUnsubscribeFrom characteristic: CBMCharacteristic) {
        // optional method
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveRead request: CBMATTRequest) {
        // optional method
    }

    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didReceiveWrite requests: [CBMATTRequest]) {
        // optional method
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBMPeripheralManager) {
        // optional method
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didPublishL2CAPChannel PSM: CBML2CAPPSM,
                           error: Error?) {
        // optional method
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didUnpublishL2CAPChannel PSM: CBML2CAPPSM,
                           error: Error?) {
        // optional method
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    func peripheralManager(_ peripheral: CBMPeripheralManager,
                           didOpen channel: CBML2CAPChannel?,
                           error: Error?) {
        // optional method
    }
}
