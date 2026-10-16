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

/// A request that uses the Attribute Protocol (ATT).
///
/// The `CBMATTRequest` class represents Attribute Protocol (ATT) read and write requests
/// from remote central devices (represented by ``CBMCentral`` objects). Remote centrals use
/// these ATT requests to read and write characteristic values on local peripherals
/// (represented by ``CBMPeripheralManager`` objects).
///
/// Local peripherals, in turn, use the properties of `CBMATTRequest` objects to respond to
/// the read and write requests appropriately, using the
/// ``CBMPeripheralManager/respond(to:withResult:)`` method.
open class CBMATTRequest: NSObject {

    /// The central that originated the request.
    open var central: CBMCentral {
        fatalError()
    }

    /// The characteristic whose value will be read or written.
    open var characteristic: CBMCharacteristic {
        fatalError()
    }

    /// The zero-based index of the first byte for the read or write request.
    open var offset: Int {
        fatalError()
    }

    /// The data being read or written.
    ///
    /// For read requests, `value` will be `nil` and should be set before responding
    /// using ``CBMPeripheralManager/respond(to:withResult:)``. For write requests,
    /// `value` will contain the data to be written.
    open var value: Data? {
        get { fatalError() }
        set { fatalError() }
    }
}

#if os(iOS) || os(macOS)
/// A native implementation of ``CBMATTRequest`` that will proxy all requests to an
/// underlying `CBATTRequest`.
///
/// This implementation will be used when reporting requests by ``CBMPeripheralManagerNative``.
public class CBMATTRequestNative: CBMATTRequest {
    internal let request: CBATTRequest
    private let _central: CBMCentral
    private let _characteristic: CBMCharacteristic

    internal init(_ request: CBATTRequest,
                  central: CBMCentral,
                  characteristic: CBMCharacteristic) {
        self.request = request
        self._central = central
        self._characteristic = characteristic
    }

    public override var central: CBMCentral {
        return _central
    }

    public override var characteristic: CBMCharacteristic {
        return _characteristic
    }

    public override var offset: Int {
        return request.offset
    }

    public override var value: Data? {
        get { return request.value }
        set { request.value = newValue }
    }

    public override var debugDescription: String {
        return "<CBMATTRequest: central: \(central.identifier), characteristic: \(characteristic.uuid), offset: \(offset)>"
    }
}
#endif

/// Mock implementation of the ``CBMATTRequest``.
///
/// This implementation will be used when reporting requests by ``CBMPeripheralManagerMock``.
/// Such requests are created when a mock central, defined using ``CBMCentralSpec``,
/// reads or writes a characteristic value.
public class CBMATTRequestMock: CBMATTRequest {
    private let _central: CBMCentral
    private let _characteristic: CBMCharacteristic
    private let _offset: Int
    private var _value: Data?
    /// The closure called when the peripheral manager responds to the request.
    private let completion: ((CBMATTRequestMock, CBMATTError.Code) -> Void)?

    internal init(central: CBMCentral,
                  characteristic: CBMCharacteristic,
                  offset: Int,
                  value: Data?,
                  completion: ((CBMATTRequestMock, CBMATTError.Code) -> Void)?) {
        self._central = central
        self._characteristic = characteristic
        self._offset = offset
        self._value = value
        self.completion = completion
    }

    public override var central: CBMCentral {
        return _central
    }

    public override var characteristic: CBMCharacteristic {
        return _characteristic
    }

    public override var offset: Int {
        return _offset
    }

    public override var value: Data? {
        get { return _value }
        set { _value = newValue }
    }

    /// Completes the request with the given result.
    internal func respond(_ result: CBMATTError.Code) {
        completion?(self, result)
    }

    public override var debugDescription: String {
        return "<CBMATTRequest: central: \(central.identifier), characteristic: \(characteristic.uuid), offset: \(offset)>"
    }
}
