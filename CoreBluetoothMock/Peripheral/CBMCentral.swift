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

/// A remote device connected to a local app, which is acting as a peripheral.
///
/// The `CBMCentral` class represents remote central devices that have connected to an app
/// implementing the peripheral role on a local device. That is, when you implement the
/// peripheral role using ``CBMPeripheralManager``, centrals that connect to the local
/// peripheral are represented by `CBMCentral` objects. Remote centrals use universally unique
/// identifiers (UUIDs), represented by `UUID` objects, to identify themselves.
open class CBMCentral: CBMPeer {

    /// The maximum amount of data, in bytes, that the central can receive in a
    /// single notification or indication.
    open var maximumUpdateValueLength: Int {
        fatalError()
    }
}

#if os(iOS) || os(macOS)
/// A native implementation of ``CBMCentral`` that will proxy all requests to an underlying `CBCentral`.
///
/// This implementation will be used when creating centrals by ``CBMPeripheralManagerNative``.
public class CBMCentralNative: CBMCentral {
    internal let central: CBCentral

    internal init(_ central: CBCentral) {
        self.central = central
    }

    public override var identifier: UUID {
        return central.identifier
    }

    public override var maximumUpdateValueLength: Int {
        return central.maximumUpdateValueLength
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? CBMCentralNative {
            return central == other.central
        }
        return false
    }

    public override var hash: Int {
        return central.hash
    }

    public override var debugDescription: String {
        return "<CBMCentral: identifier: \(identifier), maximumUpdateValueLength: \(maximumUpdateValueLength)>"
    }
}
#endif

/// Mock implementation of the ``CBMCentral``.
///
/// This implementation will be used when creating centrals by ``CBMPeripheralManagerMock``.
/// Each mock central is based on a ``CBMCentralSpec`` which is used to simulate the
/// central's behavior.
public class CBMCentralMock: CBMCentral {
    /// The specification of the simulated central.
    internal let spec: CBMCentralSpec

    internal init(basedOn spec: CBMCentralSpec) {
        self.spec = spec
    }

    public override var identifier: UUID {
        return spec.identifier
    }

    public override var maximumUpdateValueLength: Int {
        return spec.maximumUpdateValueLength
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? CBMCentralMock {
            return identifier == other.identifier
        }
        return false
    }

    public override var hash: Int {
        return identifier.hashValue
    }

    public override var debugDescription: String {
        return "<CBMCentral: identifier: \(identifier), maximumUpdateValueLength: \(maximumUpdateValueLength)>"
    }
}
