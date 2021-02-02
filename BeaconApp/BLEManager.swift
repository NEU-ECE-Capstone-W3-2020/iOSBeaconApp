import Foundation
import CoreBluetooth

@objc class BLEManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate
{
    var centralManager: CBCentralManager!
    let dispatchQueue = DispatchQueue(label:"CBqueue")
    
    var connectingPeripheral: CBPeripheral!
    var connectingUUID: CBUUID?
    var subscribedUUID: CBUUID?
    
    @objc public func setup()
    {
        centralManager = CBCentralManager(delegate: self, queue: dispatchQueue)
    }
    
    @objc public func scanForDevices(timeOut: Double) {
        // scan, then stop after timeOut
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        dispatchQueue.asyncAfter(deadline: .now() + timeOut, execute: {
            self.centralManager.stopScan()
//            self.bridge.onScanComplete();
        })
    }

    public func scanForDevices(uuid: CBUUID) {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    public func connectToDevice(device: CBPeripheral) {
        device.delegate = self
        self.connectingPeripheral = device
        centralManager.connect(connectingPeripheral, options: nil)
    }
    
    @objc public func populateServices(uuid: CBUUID) {
        connectingUUID = uuid
        scanForDevices(uuid: uuid);
    }
    
    @objc public func readFromCharacteristic(device_uuid: CBUUID, service_uuid: CBUUID, characteristic_uuid: CBUUID) {
        if (connectingUUID == device_uuid) {
            for service in connectingPeripheral.services! {
                if service.uuid == service_uuid {
                    for characteristic in service.characteristics! {
                        if characteristic.uuid == characteristic_uuid {
                            connectingPeripheral.readValue(for: characteristic)
                        }
                    }
                }
            }
        }
    }
    
    var intentToNotify = false
    @objc public func subscribeToNotifications(device_uuid: CBUUID, service_uuid: CBUUID, characteristic_uuid: CBUUID) {
        if (connectingUUID == device_uuid) {
//            bridge.onConnect()
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
//                                bridge.onNotificationsUnsupported()
                            }
                        }
                    }
                    if (!gotCharacteristic) {
//                        bridge.onNoCharacteristic()
                    }
                }
            }
        }
        else {
//            bridge.onNoConnect()
        }
    }
    
    var intentToUnsubscribe = false
    @objc public func unsubscribeToNotifications() {
        for service in connectingPeripheral.services! {
            for characteristic in service.characteristics! {
                if (characteristic.uuid == subscribedUUID) {
                    intentToUnsubscribe = true
                    connectingPeripheral.setNotifyValue(false, for: characteristic)
                }
            }
        }
    }
    
    var intentToWrite = false
    @objc public func writeToCharacteristic(device_uuid: CBUUID, service_uuid: CBUUID, characteristic_uuid: CBUUID, bytes: Data) {
        if (connectingUUID == device_uuid) {
            for service in connectingPeripheral.services! {
                if (service.uuid == service_uuid) {
                    var gotCharacteristic = false
                    for characteristic in service.characteristics! {
                        if (characteristic.uuid == characteristic_uuid) {
                            gotCharacteristic = true
                            if (!characteristic.properties.contains(CBCharacteristicProperties.write)) {
//                                bridge.onWriteFail()
                            } else if (characteristic.properties.contains(CBCharacteristicProperties.writeWithoutResponse)) {
                                intentToWrite = true
                                connectingPeripheral.writeValue(bytes, for: characteristic, type: CBCharacteristicWriteType.withoutResponse)
                            } else {
                                intentToWrite = true
                                connectingPeripheral.writeValue(bytes, for: characteristic, type: CBCharacteristicWriteType.withResponse)
                            }
                        }
                    }
                    if (!gotCharacteristic) {
//                        bridge.onWriteFail()
                    }
                }
            }
        }
    }
    
    // MARK: - centralManagerDelegate
    
    @objc open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("poweredOn")
//            bridge.onCbState("poweredOn")
        case .poweredOff:
            print("poweredOff")
//            bridge.onCbState("poweredOff")
        case .unsupported:
            print("poweredOn")
//            bridge.onCbState
        case .unknown:
            print("unknown")
//            bridge.onCbState("unknown")
        case .resetting:
            print("resetting")
//            bridge.onCbState("resetting")
        case .unauthorized:
            print("unauthorized")
//            bridge.onCbState("unauthorized")
        @unknown default:
            print("fatal error")
            fatalError()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if (connectingUUID == nil) {
            if (peripheral.name == nil){
//                bridge.onDeviceDiscovered("<no name>", uuid:peripheral.identifier.uuidString)
            }
            else{
//                bridge.onDeviceDiscovered(peripheral.name, uuid:peripheral.identifier.uuidString)
            }
        }
        else {
            if (peripheral.identifier.uuidString == connectingUUID?.uuidString) {
                connectToDevice(device: peripheral)
                centralManager.stopScan()
            }
        }
    }
    
    // didConnect gets called twice for some reason so we use this bool
    var alreadyConnected = false;
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if(!alreadyConnected){
            peripheral.discoverServices(nil)
            alreadyConnected = true
        }
        else{
            alreadyConnected = false
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
//        bridge.onNoConnect()
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectingPeripheral = nil
        connectingUUID = nil
//        bridge.onDisconnect()
    }
    
    // MARK: - peripheralDelegate

    var serviceCounter = 0
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for: service)
            serviceCounter += 1
        }
    }
    
    // keep an array of populated CBServices to send all populated services at once
    var services = [CBService]()
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        serviceCounter -= 1
        
        services.append(service)
        
        if (serviceCounter == 0) {
//            bridge.onServicesPopulated(services)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (intentToWrite) {
//            bridge.onWriteSuccess()
            intentToWrite = false
        } else if (characteristic.isNotifying) {
//            bridge.onValueChanged(characteristic.value)
        } else {
//            bridge.onRead(characteristic.value)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if (intentToUnsubscribe) {
            centralManager.cancelPeripheralConnection(connectingPeripheral)
            intentToUnsubscribe = false
            subscribedUUID = nil
        } else if (intentToNotify && !characteristic.isNotifying) {
//            bridge.onNoRegister()
            intentToNotify = false
        } else if (intentToNotify && characteristic.isNotifying) {
            subscribedUUID = characteristic.uuid
        }
    }
}
