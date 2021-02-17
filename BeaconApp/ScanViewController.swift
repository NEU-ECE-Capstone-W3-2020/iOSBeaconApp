import UIKit
import CoreBluetooth

class ScanViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var ble = BLEManager()
    var pairedDevice: BeaconDevice?
    var pairedPeripheral: CBPeripheral?
   
    var discoveredPeripherals = Array<CBPeripheral>()
    
    @IBOutlet weak var deviceList: UITableView!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var scanButton: UIButton!
    //var selectedDeviceName: String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if (!ble.isSetup) {
            print("Setting up BLE")
            ble.setup()
        }
        disconnectButton.isHidden = !ble.isConnected
        scanButton.isHidden = ble.isConnected
        deviceList.dataSource = self
        deviceList.delegate = self
        deviceList.register(UITableViewCell.self, forCellReuseIdentifier: "deviceName")
    }
    
    @IBAction func scanButton(_ sender: Any) {
        print("Scanning")
        ble.discoveredPeripheralNames.removeAll()
        ble.discoveredPeripherals.removeAll()
        ble.scanForDevices(timeOut: 5, discovered: { (name) -> Void in
            DispatchQueue.main.async {
                self.deviceList.reloadData()
            }
        })
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        let deviceName = cell.textLabel?.text ?? "<no name>"
        
        if (self.scanButton.isHidden && deviceName == self.pairedDevice?.name) { return }
        
        ble.connectToDevice(name: deviceName, connect: { (success) -> Void in
            if (success) {
                
                self.pairedDevice?.isConnected = true
               
                self.pairedDevice?.name = deviceName
                self.pairedPeripheral  = self.ble.connectingPeripheral
                self.pairedDevice?.address = self.ble.connectingUUID?.uuidString ?? " "
                self.pairedDevice?.peripheral = self.pairedPeripheral
               
                DispatchQueue.main.async { [self] in
                    scanButton.isHidden = true
                    disconnectButton.isHidden = false
                }
                
            } else {
                print("todo")
            }
        }, disconnect: { () -> Void in
           
            DispatchQueue.main.async {
                //Switch back to the scan button, set the connected device to nil
                self.disconnectButton.isHidden = true
                self.scanButton.isHidden = false
            }
        }
        )
        
        if pairedPeripheral != nil{
            pairedDevice = BeaconDevice(isConnected: true, deviceName: pairedPeripheral?.name ?? "noname", deviceAddress:  pairedPeripheral?.identifier.uuidString ?? "noid",peripheral: pairedPeripheral!)
        }
    }
    
    @IBAction func disconnectButtonPressed(_ sender: Any) {
        ble.disconnect()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ble.discoveredPeripheralNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "deviceName", for: indexPath)
        cell.textLabel!.text = ble.discoveredPeripheralNames[indexPath.item]
        //cell.detailTextLabel!.text = "\(ble.discoveredPeripherals[indexPath.item].identifier)"
        cell.backgroundColor = UIColor.black
        cell.textLabel?.textColor = UIColor.white
        return cell
    }
}


