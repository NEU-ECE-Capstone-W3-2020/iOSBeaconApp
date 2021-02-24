import Foundation
import CoreBluetooth
import UIKit

class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate
{
    // BLE
    var centralManager: CBCentralManager!
    let dispatchQueue = DispatchQueue(label:"CBqueue")
    let plotQueue = DispatchQueue(label: "Plot")
    var discoveredPeripheralNames = Array<String>()
    var discoveredPeripherals = Array<CBPeripheral>()
    var connectingPeripheral: CBPeripheral!
    var connectingUUID: CBUUID?
    var subscribedUUID: CBUUID?
    var isConnected: Bool = false
    var isSetup: Bool = false
    var isInBackground: Bool = false
    var notifyCharacteristic: CBCharacteristic!
    
    public func setup() {
        centralManager = CBCentralManager(delegate: self, queue: dispatchQueue, options: [CBCentralManagerOptionRestoreIdentifierKey : "Capstone"])
        isSetup = true
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init("haptic"), object: nil, queue: OperationQueue.main, using: { (notification) in
            let byteArray = NSData(bytes: [0xFF, 0x64] as [UInt8], length: 2)
            self.writeToCharacteristic(device_uuid: self.connectingUUID!, service_uuid: CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"), characteristic_uuid: CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"), bytes: byteArray as Data)
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init("stop"), object: nil, queue: OperationQueue.main, using: { (notification) in
            let byteArray = NSData(bytes: [0x00, 0x00] as [UInt8], length: 2)
            self.writeToCharacteristic(device_uuid: self.connectingUUID!, service_uuid: CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"), characteristic_uuid: CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"), bytes: byteArray as Data)
        })
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init("background"), object: nil, queue: OperationQueue.main, using: { (notification) in
            self.isInBackground = notification.object as! Bool
            print("isInBackground: \(self.isInBackground)")
        })
    }
    
    // ScanView Callbacks
    typealias ScanCallback = (Bool) -> Void
    var connectCallback: ScanCallback?
    typealias DiscoverCallback = (String) -> Void
    var discoverCallback: DiscoverCallback?
    typealias DisconnectCallback = () -> Void
    var disconnectCallback: DisconnectCallback?
    
    // Alerts
    func showAlert(message: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            let dismissAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
            controller.addAction(dismissAction)
            UIApplication.shared.keyWindow?.rootViewController?.present(controller, animated: true, completion: nil)
        }
    }
    
    public func scanForDevices(timeOut: Double, discovered: @escaping (String) -> Void) {
    self.discoverCallback = discovered
        centralManager.scanForPeripherals(withServices: [CBUUID(string:
            // Nordic BLE service
            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")], options: nil)
        
        // Stop scan after timeout
        dispatchQueue.asyncAfter(deadline: .now() + timeOut, execute: {
            self.centralManager.stopScan()
        })
        
    }
    
    public func scanForDevices() {
        centralManager.scanForPeripherals(withServices: [CBUUID(string:
            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")], options: nil)
    }
    
    var intentToConnect: Bool = false
    var intendedName: String?
    func connectToDevice(name: String, connect: @escaping (Bool) -> Void, disconnect: @escaping () -> Void) {
        self.connectCallback = connect
        self.disconnectCallback = disconnect
        
        intentToConnect = true
        intendedName = name
        
        self.scanForDevices()
        
        connect(true)
    }
    
    public func populateServices(uuid: CBUUID) {
        connectingUUID = uuid
        scanForDevices()
    }
    
    public func readFromCharacteristic(device: CBPeripheral, service: CBUUID, characteristic: CBUUID) -> Data {
        var readValue = Data()
        for cb_service in device.services! {
            if cb_service.uuid == service {
                for cb_characteristic in cb_service.characteristics! {
                    if cb_characteristic.uuid == characteristic {
                        if (cb_characteristic.value != nil) {
                            readValue = cb_characteristic.value!
                        }
                        else {
                            print("Characteristic value is nil")
                        }
                    }
                }
            }
        }
        return readValue
    }
    
    var intentToNotify = false
    public func subscribeToNotifications(device_uuid: CBUUID, service_uuid: CBUUID, characteristic_uuid: CBUUID) {
        if (connectingUUID == device_uuid) {
            // TODO: ScanView, device connected
            for service in connectingPeripheral.services! {
                if (service.uuid == service_uuid) {
                    var gotCharacteristic = false
                    for characteristic in service.characteristics! {
                        if (characteristic.uuid == characteristic_uuid) {
                            gotCharacteristic = true
                            if (characteristic.properties.contains(CBCharacteristicProperties.notify)) {
                                intentToNotify = true
                                connectingPeripheral.setNotifyValue(true, for: characteristic)
                            } else {
                                showAlert(message: "BLE notifications unsupported for characteristic")
                            }
                        }
                    }
                    if (!gotCharacteristic) {
                        showAlert(message: "Could not find required BLE characteristic")
                    }
                }
            }
        }
        else {
            showAlert(message: "Failed to connect device")
        }
    }
    
    var intentToDisconnect = false
    public func disconnect() {
        intentToDisconnect = true
        centralManager.cancelPeripheralConnection(connectingPeripheral)
    }
    
    // TODO: Haptics
    var intentToWrite = false
    public func writeToCharacteristic(device_uuid: CBUUID, service_uuid: CBUUID, characteristic_uuid: CBUUID, bytes: Data) {
        if (connectingUUID == device_uuid) {
            for service in connectingPeripheral.services! {
                if (service.uuid == service_uuid) {
                    var gotCharacteristic = false
                    for characteristic in service.characteristics! {
                        if (characteristic.uuid == characteristic_uuid) {
                            gotCharacteristic = true
                            if (!characteristic.properties.contains(CBCharacteristicProperties.write)) {
                                showAlert(message: "Write to BLE characteristic failed")
                            } else if (characteristic.properties.contains(CBCharacteristicProperties.writeWithoutResponse)) {
                                intentToWrite = true
                                connectingPeripheral.writeValue(bytes, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
                                connectingPeripheral.readValue(for: characteristic)
                            } else {
                                intentToWrite = true
                                connectingPeripheral.writeValue(bytes, for: characteristic, type: CBCharacteristicWriteType.withResponse)
                            }
                        }
                    }
                    if (!gotCharacteristic) {
                        showAlert(message: "Write to BLE characteristic failed")
                    }
                }
            }
        }
    }
    
    // MARK: - centralManagerDelegate
    
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("poweredOn")
        case .poweredOff:
            print("poweredOff")
        case .unsupported:
            print("unsupported")
        case .unknown:
            print("unknown")
        case .resetting:
            print("resetting")
        case .unauthorized:
            print("unauthorized")
        @unknown default:
            print("error")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "<no name>"
        
        if (intentToConnect) {
            if name == self.intendedName {
                peripheral.delegate = self
                self.connectingPeripheral = peripheral
                self.connectingUUID = CBUUID(string: peripheral.identifier.uuidString)
                centralManager.connect(peripheral, options: nil)
                intentToConnect = false
            }
        } else {
            self.discoveredPeripheralNames.append(name)
            self.discoveredPeripherals.append(peripheral)
            self.discoverCallback!(name)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.isConnected = true
//        self.connectCallback!(true)
        self.connectingPeripheral = peripheral
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        showAlert(message: "Failed to connect device")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.isConnected = false
        
        if (intentToDisconnect) {
            connectingPeripheral = nil
            connectingUUID = nil
            
            self.disconnectCallback!()
            
            showAlert(message: "Disconnected from device")
            intentToDisconnect = false
        } else {
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        self.centralManager = central
        self.centralManager.delegate = self
    }
    
    // MARK: - peripheralDelegate
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("Service: \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    var rxCharacteristic: CBCharacteristic!
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            print("Characteristic: \(characteristic.uuid.uuidString)")
            switch characteristic.properties {
                case .indicate:
                    print("indicate")
                case .notify:
                    print("notify")
                case .write:
                    print("write")
                case .writeWithoutResponse:
                    print("writeWithoutResponse")
                case .read:
                    print("read")
                    peripheral.readValue(for: characteristic)
                default:
                    print("unknown")
            }
            
            if (characteristic.uuid.uuidString == "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") {
                rxCharacteristic = characteristic
            }
        }
    }
    
    var ourCharacteristicValue = "<no data>"
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.value != nil {
            if (characteristic.uuid.uuidString == "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") {
                if let cv = characteristic.value {
                    ourCharacteristicValue = String(data: cv, encoding: .ascii) ?? ourCharacteristicValue
                    print(ourCharacteristicValue)
                }
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Wrote value to characteristic \(characteristic.uuid.uuidString)")
//        peripheral.readValue(for: characteristic)
    }
    
    public func updateCharVal(val: String) {
        self.ourCharacteristicValue = val
        self.connectingPeripheral.writeValue(val.data(using: .ascii)!, for: rxCharacteristic, type: .withResponse)
    }
}
