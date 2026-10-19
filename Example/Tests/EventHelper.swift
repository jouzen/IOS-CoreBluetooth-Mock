/*
* Copyright (c) 2020, Nordic Semiconductor
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
@testable import nRF_Blinky
@testable import CoreBluetoothMock

class Sim {

    static func post(_ notification: Notification) {
        NotificationCenter.default.post(notification)
    }

    static func dispose(_ observer: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(observer)
    }

    private static func on(_ name: Notification.Name, do action: @escaping (Notification) -> ()) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil, using: action)
    }

    static func onBlinkyDiscovery(do action: @escaping (BlinkyPeripheral) -> ()) {
        var observer: NSObjectProtocol?
        observer = on(.newPeripheral) { notification in
            if let userInfo = notification.userInfo,
               let blinky = userInfo["blinky"] as? BlinkyPeripheral {
                action(blinky)
            }
            dispose(observer!)
        }
    }

}
extension XCTestCase {

    /// Turns the mock Bluetooth adapter off and lets the app observe the change.
    ///
    /// The app is shared by all tests, and its central manager reports state changes
    /// asynchronously. If the next test powers the adapter on again before the app was
    /// notified, the app never sees the adapter off and keeps its state from the
    /// previous test, e.g. a pending connection, which stops scanning in the next test.
    func powerOffAndSettle() {
        CBMCentralManagerMock.simulatePowerOff()
        let settled = XCTestExpectation(description: "App notified")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.2)
    }

    /// Pops all view controllers pushed by a test and waits until the scanner
    /// is on top and no transition is in progress.
    ///
    /// A view controller that is still being pushed or popped when the next test
    /// starts would prevent the scanner from restarting scanning, as it does that
    /// when it appears.
    func returnToScanner() {
        let windowScene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        let navigationController = windowScene.windows.first!.rootViewController as! UINavigationController
        let settled = XCTestExpectation(description: "Scanner is visible")
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if navigationController.transitionCoordinator != nil {
                return
            }
            if navigationController.viewControllers.count > 1 {
                navigationController.popToRootViewController(animated: false)
                return
            }
            timer.invalidate()
            settled.fulfill()
        }
        wait(for: [settled], timeout: 5)
        timer.invalidate()
    }
}
