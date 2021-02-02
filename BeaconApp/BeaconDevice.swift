import Foundation
import CoreBluetooth

struct BeaconDevice: Equatable {
    var isConnected = false
    var name = ""
    var address = ""
    var signal = -1
    var power = -1
    var peripheral:CBPeripheral?
    //Two devices are equal if they have the same address
    static func == (left: BeaconDevice, right:BeaconDevice) -> Bool {
        return left.address == right.address
    }
    
    init(isConnected: Bool, deviceName: String, deviceAddress: String, peripheral: CBPeripheral?){
        self.isConnected = isConnected
        self.name  = deviceName
        self.address = deviceAddress
        self.signal = -1
        self.power = -1
        self.peripheral = peripheral
    }
    init(){
        self.isConnected = false
        self.name  = "none"
        self.address = "none"
        self.signal = -1
        self.power = -1
        self.peripheral = nil
    }
}
