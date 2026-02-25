//
//  PolarManager.swift
//  URAP Polar H10 V1
//
//  Manages Polar H10 Bluetooth connections and data streaming
//  Data collection is handled by RecordingCoordinator
//

import Foundation
import Combine
import PolarBleSdk
import RxSwift
import CoreBluetooth
import UIKit

// MARK: - Data Point Models

struct HeartRateDataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let monotonicTimestamp: TimeInterval
    let value: UInt8

    init(timestamp: Date, monotonicTimestamp: TimeInterval, value: UInt8) {
        self.id = UUID()
        self.timestamp = timestamp
        self.monotonicTimestamp = monotonicTimestamp
        self.value = value
    }
}

struct RRIntervalDataPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let monotonicTimestamp: TimeInterval
    let value: UInt16

    init(timestamp: Date, monotonicTimestamp: TimeInterval, value: UInt16) {
        self.id = UUID()
        self.timestamp = timestamp
        self.monotonicTimestamp = monotonicTimestamp
        self.value = value
    }
}

// MARK: - HRV Window Configuration

enum HRVWindow: String, CaseIterable, Identifiable {
    case ultraShort1min = "1 Minute"
    case ultraShort2min = "2 Minutes"
    case short5min = "5 Minutes"
    case extended10min = "10 Minutes"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .ultraShort1min: return 60
        case .ultraShort2min: return 120
        case .short5min: return 300
        case .extended10min: return 600
        }
    }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .ultraShort1min: return "Ultra-short term (1 min)"
        case .ultraShort2min: return "Ultra-short term (2 min)"
        case .short5min: return "Short-term (5 min) - Research standard"
        case .extended10min: return "Extended (10 min)"
        }
    }
}

// MARK: - Connected Sensor Model (Display Only)

/// Represents a connected Polar sensor for display purposes
/// Recording data collection is handled by RecordingCoordinator/SensorDataCollector
/// Display data (charts, stats, HRV) is maintained here for live UI
class ConnectedSensor: ObservableObject, Identifiable {
    let id: String
    let deviceName: String

    // Connection & live values
    @Published var connectionState: ConnectionState = .connecting
    @Published var heartRate: UInt8 = 0
    @Published var rrInterval: UInt16 = 0
    @Published var batteryLevel: UInt = 0
    @Published var lastUpdate: Date = Date()

    // Display data for charts (rolling buffers)
    @Published var heartRateHistory: [HeartRateDataPoint] = []
    @Published var rrIntervalHistory: [RRIntervalDataPoint] = []

    // Statistics (updated as data arrives)
    @Published var minHeartRate: UInt8 = 0
    @Published var maxHeartRate: UInt8 = 0
    private var hrSum: UInt64 = 0
    private var hrCount: Int = 0
    var averageHeartRate: UInt8 {
        hrCount > 0 ? UInt8(hrSum / UInt64(hrCount)) : 0
    }

    // HRV Analysis
    @Published var hrvWindow: HRVWindow = .short5min
    @Published var sdnn: Double = 0
    @Published var rmssd: Double = 0
    @Published var hrvSampleCount: Int = 0

    // Timing
    var sessionStartTime: Date?
    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var hrDisposable: Disposable?

    init(deviceId: String, deviceName: String) {
        self.id = deviceId
        self.deviceName = deviceName
        self.sessionStartTime = Date()
    }

    deinit {
        hrDisposable?.dispose()
        print("ConnectedSensor \(id) deallocated")
    }

    var displayId: String {
        String(id.suffix(6))
    }

    var isActive: Bool {
        connectionState == .connected && heartRate > 0
    }

    // MARK: - Display Data Methods

    /// Add heart rate data point for live chart display
    func addHeartRateDataPoint(_ value: UInt8) {
        let now = Date()
        let dataPoint = HeartRateDataPoint(
            timestamp: now,
            monotonicTimestamp: ProcessInfo.processInfo.systemUptime,
            value: value
        )
        heartRateHistory.append(dataPoint)

        // Trim to 5 minutes for display
        let cutoff = now.addingTimeInterval(-300)
        heartRateHistory.removeAll { $0.timestamp < cutoff }

        // Update statistics
        hrSum += UInt64(value)
        hrCount += 1
        if value > maxHeartRate { maxHeartRate = value }
        if value < minHeartRate || minHeartRate == 0 { minHeartRate = value }
    }

    /// Add RR interval data point for live chart display
    func addRRIntervalDataPoint(_ value: UInt16) {
        let now = Date()
        let dataPoint = RRIntervalDataPoint(
            timestamp: now,
            monotonicTimestamp: ProcessInfo.processInfo.systemUptime,
            value: value
        )
        rrIntervalHistory.append(dataPoint)

        // Trim to 10 minutes for HRV analysis window
        let cutoff = now.addingTimeInterval(-600)
        rrIntervalHistory.removeAll { $0.timestamp < cutoff }
    }

    /// Calculate HRV metrics from display buffer
    func calculateHRVMetrics() {
        let cutoff = Date().addingTimeInterval(-hrvWindow.seconds)
        let windowedRR = rrIntervalHistory.filter { $0.timestamp >= cutoff }
        hrvSampleCount = windowedRR.count

        guard windowedRR.count >= 5 else {
            sdnn = 0
            rmssd = 0
            return
        }

        let values = windowedRR.map { Double($0.value) }

        // SDNN
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        sdnn = sqrt(variance)

        // RMSSD
        guard values.count >= 2 else { rmssd = 0; return }
        var sumSquaredDiffs: Double = 0
        for i in 1..<values.count {
            let diff = values[i] - values[i - 1]
            sumSquaredDiffs += diff * diff
        }
        rmssd = sqrt(sumSquaredDiffs / Double(values.count - 1))
    }

    enum ConnectionState {
        case connecting
        case connected
        case disconnected

        var displayText: String {
            switch self {
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            }
        }
    }
}

// MARK: - Polar Manager

/// Manages Polar H10 Bluetooth connections and data streaming
class PolarManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isBluetoothOn = false
    @Published var isScanning = false
    @Published var discoveredDevices: [PolarDeviceInfo] = []
    @Published var connectedSensors: [ConnectedSensor] = []
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var api: PolarBleApi?
    private let disposeBag = DisposeBag()
    private var sensors: [String: ConnectedSensor] = [:]

    // Background support
    private var devicesToMaintain: Set<String> = []
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskQueue = DispatchQueue(label: "com.urap.backgroundTask")
    private var reconnectionAttempts: [String: Int] = [:]
    private let maxReconnectionAttempts = 5

    // Recording coordinator reference
    private var recordingCoordinator: RecordingCoordinator {
        RecordingCoordinator.shared
    }

    // Singleton
    static let shared = PolarManager()

    // MARK: - Initialization

    override init() {
        super.init()

        api = PolarBleApiDefaultImpl.polarImplementation(
            DispatchQueue.main,
            features: [
                .feature_hr,
                .feature_battery_info,
                .feature_polar_online_streaming
            ]
        )

        guard var initializedApi = api else {
            fatalError("Failed to initialize PolarBleApi")
        }

        initializedApi.polarFilter(true)
        initializedApi.observer = self
        initializedApi.deviceInfoObserver = self
        initializedApi.deviceFeaturesObserver = self
        initializedApi.powerStateObserver = self

        isBluetoothOn = initializedApi.isBlePowered

        if !isBluetoothOn {
            errorMessage = "Bluetooth is turned off"
        }
    }

    // MARK: - Device Search

    func startScanning() {
        guard let api = api else {
            errorMessage = "Bluetooth API not initialized"
            return
        }

        discoveredDevices.removeAll()
        isScanning = true
        errorMessage = nil

        Task {
            do {
                for try await device in api.searchForDevice().values {
                    await MainActor.run {
                        if !discoveredDevices.contains(where: { $0.deviceId == device.deviceId }) {
                            discoveredDevices.append(device)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    isScanning = false
                }
            }
        }
    }

    func stopScanning() {
        isScanning = false
    }

    // MARK: - Connection Management

    func connect(to device: PolarDeviceInfo) {
        guard let api = api else {
            errorMessage = "Bluetooth API not initialized"
            return
        }

        stopScanning()
        errorMessage = nil

        let sensor = ConnectedSensor(deviceId: device.deviceId, deviceName: device.name)
        sensors[device.deviceId] = sensor
        updateConnectedSensorsList()

        devicesToMaintain.insert(device.deviceId)
        reconnectionAttempts[device.deviceId] = 0

        do {
            try api.connectToDevice(device.deviceId)
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
            sensors.removeValue(forKey: device.deviceId)
            devicesToMaintain.remove(device.deviceId)
            updateConnectedSensorsList()
        }
    }

    func disconnect(deviceId: String) {
        guard let sensor = sensors[deviceId] else { return }
        guard let api = api else {
            errorMessage = "Bluetooth API not initialized"
            return
        }

        devicesToMaintain.remove(deviceId)
        reconnectionAttempts.removeValue(forKey: deviceId)

        sensor.hrDisposable?.dispose()

        do {
            try api.disconnectFromDevice(deviceId)
        } catch {
            errorMessage = "Disconnect failed: \(error.localizedDescription)"
        }

        // Remove sensor from recording if active
        Task { @MainActor in
            recordingCoordinator.removeSensor(id: deviceId)
        }

        sensors.removeValue(forKey: deviceId)
        updateConnectedSensorsList()
    }

    private func updateConnectedSensorsList() {
        connectedSensors = Array(sensors.values).sorted { $0.id < $1.id }
    }

    // MARK: - Recording Controls

    /// Start recording on all connected sensors
    func startRecording(recordingId: String) {
        let sensorList = sensors.values.map { (id: $0.id, name: $0.deviceName) }
        Task { @MainActor in
            recordingCoordinator.startRecording(sensors: sensorList, recordingId: recordingId)
        }
    }

    /// Pause recording
    func pauseRecording() {
        Task { @MainActor in
            recordingCoordinator.pauseRecording()
        }
    }

    /// Resume recording
    func resumeRecording() {
        Task { @MainActor in
            recordingCoordinator.resumeRecording()
        }
    }

    /// Stop recording and save
    func stopRecording() {
        Task { @MainActor in
            await recordingCoordinator.stopRecording()
        }
    }

    /// Cancel recording without saving
    func cancelRecording() {
        Task { @MainActor in
            recordingCoordinator.cancelRecording()
        }
    }

    // MARK: - Background Lifecycle

    func handleAppBackground() {
        print("App entering background")

        backgroundTaskQueue.sync {
            guard backgroundTask == .invalid else { return }

            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
        }

        print("Background mode activated")
    }

    func handleAppForeground() {
        print("App entering foreground")

        endBackgroundTask()
        reconnectLostDevices()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.restartStreamsForConnectedDevices()
        }

        print("Foreground mode activated")
    }

    private func endBackgroundTask() {
        backgroundTaskQueue.sync {
            guard backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Reconnection

    private func reconnectLostDevices() {
        for deviceId in devicesToMaintain {
            guard let sensor = sensors[deviceId] else {
                attemptReconnection(deviceId: deviceId)
                continue
            }

            if sensor.connectionState != .connected {
                attemptReconnection(deviceId: deviceId)
            }
        }
    }

    private func attemptReconnection(deviceId: String) {
        let attempts = reconnectionAttempts[deviceId] ?? 0

        guard attempts < maxReconnectionAttempts else {
            errorMessage = "Failed to reconnect to device \(deviceId.suffix(6))"
            return
        }

        reconnectionAttempts[deviceId] = attempts + 1
        let delay = Double(attempts) * 2.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self,
                  let api = self.api,
                  self.devicesToMaintain.contains(deviceId) else { return }

            do {
                try api.connectToDevice(deviceId)
            } catch {
                if attempts + 1 < self.maxReconnectionAttempts {
                    self.attemptReconnection(deviceId: deviceId)
                } else {
                    self.errorMessage = "Failed to reconnect to device \(deviceId.suffix(6))"
                }
            }
        }
    }

    // MARK: - Data Streaming

    private func restartStreamsForConnectedDevices() {
        for (deviceId, sensor) in sensors {
            if sensor.connectionState == .connected {
                restartStreams(for: deviceId)
            }
        }
    }

    private func restartStreams(for deviceId: String) {
        guard let sensor = sensors[deviceId] else { return }

        sensor.hrDisposable?.dispose()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startHeartRateStream(for: deviceId)
        }
    }

    private func startHeartRateStream(for deviceId: String) {
        guard let sensor = sensors[deviceId],
              let api = api else { return }

        // Dispose any existing subscription to prevent double-subscription
        sensor.hrDisposable?.dispose()

        sensor.hrDisposable = api.startHrStreaming(deviceId)
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self, weak sensor] event in
                guard let self = self, let sensor = sensor else { return }

                switch event {
                case .next(let data):
                    guard let hrData = data.first else { return }

                    // Update display values
                    sensor.heartRate = hrData.hr
                    sensor.lastUpdate = Date()

                    // Add to display buffer for charts
                    sensor.addHeartRateDataPoint(hrData.hr)

                    // Handle RR intervals from HR stream
                    for rrMs in hrData.rrsMs {
                        let rrValue = UInt16(rrMs)
                        sensor.rrInterval = rrValue
                        sensor.addRRIntervalDataPoint(rrValue)
                    }

                    // Periodically recalculate HRV
                    sensor.calculateHRVMetrics()

                    // Route to recording coordinator
                    Task { @MainActor in
                        await self.recordingCoordinator.routeHeartRateData(
                            sensorId: deviceId,
                            value: hrData.hr
                        )

                        for rrMs in hrData.rrsMs {
                            await self.recordingCoordinator.routeRRIntervalData(
                                sensorId: deviceId,
                                value: UInt16(rrMs)
                            )
                        }
                    }

                case .error(let error):
                    print("HR stream error for \(deviceId): \(error.localizedDescription)")

                case .completed:
                    print("HR stream completed for \(deviceId)")
                }
            }
    }

}

// MARK: - PolarBleApiObserver

extension PolarManager: PolarBleApiObserver {
    func deviceConnecting(_ polarDeviceInfo: PolarDeviceInfo) {
        DispatchQueue.main.async {
            self.sensors[polarDeviceInfo.deviceId]?.connectionState = .connecting
        }
    }

    func deviceConnected(_ polarDeviceInfo: PolarDeviceInfo) {
        DispatchQueue.main.async {
            if let sensor = self.sensors[polarDeviceInfo.deviceId] {
                sensor.connectionState = .connected
                self.reconnectionAttempts[polarDeviceInfo.deviceId] = 0

                // Add sensor to recording if recording is active
                Task { @MainActor in
                    if self.recordingCoordinator.state.isActive {
                        self.recordingCoordinator.addSensor(
                            id: polarDeviceInfo.deviceId,
                            name: polarDeviceInfo.name
                        )
                    }
                }
            }
            self.errorMessage = nil
            self.updateConnectedSensorsList()
        }
    }

    func deviceDisconnected(_ polarDeviceInfo: PolarDeviceInfo, pairingError: Bool) {
        DispatchQueue.main.async {
            self.sensors[polarDeviceInfo.deviceId]?.connectionState = .disconnected

            if pairingError {
                self.errorMessage = "Pairing error with \(polarDeviceInfo.name)"
            }

            if self.devicesToMaintain.contains(polarDeviceInfo.deviceId) {
                self.attemptReconnection(deviceId: polarDeviceInfo.deviceId)
            }

            // Remove sensor from recording
            Task { @MainActor in
                self.recordingCoordinator.removeSensor(id: polarDeviceInfo.deviceId)
            }
        }
    }
}

// MARK: - PolarBleApiDeviceInfoObserver

extension PolarManager: PolarBleApiDeviceInfoObserver {
    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: PolarBleSdk.BleBasClient.ChargeState) {}

    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {}

    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        DispatchQueue.main.async {
            self.sensors[identifier]?.batteryLevel = batteryLevel
        }
    }

    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {}

    func hrFeatureReady(_ identifier: String) {}
}

// MARK: - PolarBleApiDeviceFeaturesObserver

extension PolarManager: PolarBleApiDeviceFeaturesObserver {
    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdk.PolarBleSdkFeature) {
        DispatchQueue.main.async {
            switch feature {
            case .feature_hr:
                self.startHeartRateStream(for: identifier)
            default:
                break
            }
        }
    }

    func ftpFeatureReady(_ identifier: String) {}

    func streamingFeaturesReady(_ identifier: String, streamingFeatures: Set<PolarBleSdk.PolarDeviceDataType>) {}
}

// MARK: - PolarBleApiPowerStateObserver

extension PolarManager: PolarBleApiPowerStateObserver {
    func blePowerOn() {
        DispatchQueue.main.async {
            self.isBluetoothOn = true
            if self.errorMessage == "Bluetooth is turned off" {
                self.errorMessage = nil
            }
        }
    }

    func blePowerOff() {
        DispatchQueue.main.async {
            self.isBluetoothOn = false
            self.errorMessage = "Bluetooth is turned off"
        }
    }
}
