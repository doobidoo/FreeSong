import Foundation
import CoreBluetooth

// MARK: - Notifications

extension Notification.Name {
    public static let pageTurnerDidAdvance = Notification.Name("pageTurnerDidAdvance")
    public static let pageTurnerDidReverse = Notification.Name("pageTurnerDidReverse")
    public static let pageTurnerDidConnect = Notification.Name("pageTurnerDidConnect")
    public static let pageTurnerDidDisconnect = Notification.Name("pageTurnerDidDisconnect")
}

// MARK: - Known BLE Services

enum PageTurnerService {
    static let airTurn = CBUUID(string: "1D14D6EC-FB63-4FA1-B6B4-9007E1CEEF8A")
    static let pageFlip = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    static let midiBLE = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    static let battery = CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB")

    static let all: [CBUUID] = [airTurn, pageFlip, midiBLE]
}

// MARK: - BLEPageTurnerManager

public final class BLEPageTurnerManager: NSObject, ObservableObject {
    public static let shared = BLEPageTurnerManager()

    @Published public var isConnected = false
    @Published public var isScanning = false
    @Published public var deviceName: String?
    @Published public var batteryLevel: Int?

    public var autoConnectEnabled = true

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?
    private let scanQueue = DispatchQueue(label: "com.freesong.ble-scan")

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: scanQueue)
    }

    // MARK: - Public API

    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: PageTurnerService.all,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    public func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    public func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Private

    private func connect(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        Task { @MainActor in self.deviceName = peripheral.name }
        centralManager.stopScan()
        Task { @MainActor in self.isScanning = false }
        peripheral.delegate = self
        peripheral.discoverServices(PageTurnerService.all)
    }

    private func post(_ name: Notification.Name) {
        Task { @MainActor in
            NotificationCenter.default.post(name: name, object: nil)
        }
    }

    private func handlePedalData(_ data: Data) {
        guard let byte = data.first else { return }
        switch byte {
        case 0x01, 0x10, 0x40, 0x80:
            post(.pageTurnerDidAdvance)
        case 0x02, 0x20:
            post(.pageTurnerDidReverse)
        default:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEPageTurnerManager: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                if autoConnectEnabled { startScanning() }
            case .poweredOff:
                isConnected = false
                deviceName = nil
            default:
                break
            }
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard connectedPeripheral == nil else { return }
        connect(peripheral)
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        Task { @MainActor in
            isConnected = true
            NotificationCenter.default.post(name: .pageTurnerDidConnect, object: nil)
        }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedPeripheral = nil
        Task { @MainActor in deviceName = nil }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            isConnected = false
            deviceName = nil
            NotificationCenter.default.post(name: .pageTurnerDidDisconnect, object: nil)
            if autoConnectEnabled { startScanning() }
        }
        connectedPeripheral = nil
        dataCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BLEPageTurnerManager: CBPeripheralDelegate {
    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if service.uuid == PageTurnerService.battery {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: "2A19") {
            let level = data.withUnsafeBytes { $0.load(as: UInt8.self) }
            Task { @MainActor in self.batteryLevel = Int(level) }
            return
        }
        handlePedalData(data)
    }

    nonisolated public func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {}
}
