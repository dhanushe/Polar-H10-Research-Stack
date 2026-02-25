//
//  DashboardView.swift
//  URAP Polar H10 V1
//
//  Modern dashboard with global recording controls and beautiful UI
//

import SwiftUI
import Combine
import PolarBleSdk

struct DashboardView: View {
    @StateObject private var polarManager = PolarManager.shared
    @StateObject private var recordingCoordinator = RecordingCoordinator.shared
    @State private var showDeviceList = false
    @State private var currentTime = Date()
    @State private var showRecordingSavedAlert = false
    @State private var showRecordingError = false
    @State private var showRecordingIdSheet = false
    @State private var recordingIdInput: String = ""
    @State private var recordingIdError: String?
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient - adapts to light/dark mode
                AppTheme.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Global Recording Controls (if sensors connected)
                    if !polarManager.connectedSensors.isEmpty {
                        globalRecordingControls
                            .padding(.horizontal)
                            .padding(.top, AppTheme.spacing.md)
                    }

                    // Sensors Grid or Empty State
                    if polarManager.connectedSensors.isEmpty {
                        emptyState
                    } else {
                        sensorsScrollView
                    }

                    // Error Message
                    if let error = polarManager.errorMessage {
                        errorBanner(error)
                            .padding()
                    }
                }

                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addSensorButton
                    }
                }
                .padding(AppTheme.spacing.lg)
                .padding(.bottom, polarManager.errorMessage != nil ? 60 : 0)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showDeviceList) {
                DeviceListView(polarManager: polarManager, isPresented: $showDeviceList)
            }
            .onReceive(timer) { _ in
                if recordingCoordinator.state.isRecording {
                    currentTime = Date()
                }
            }
            .onChange(of: recordingCoordinator.state) { oldState, newState in
                // Show saved alert when transitioning from saving to idle
                if case .saving = oldState, case .idle = newState {
                    showRecordingSavedAlert = true
                }
                // Show error if there's an error state
                if case .error = newState {
                    showRecordingError = true
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: AppTheme.spacing.sm) {
                    if showRecordingSavedAlert {
                        recordingSavedToast
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showRecordingSavedAlert)
                            .onAppear {
                                // Auto-dismiss after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation {
                                        showRecordingSavedAlert = false
                                    }
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    showRecordingSavedAlert = false
                                }
                            }
                    }
                }
                .padding(.bottom, 100)
                .padding(.horizontal, AppTheme.spacing.lg)
            }
        }
    }

    // MARK: - Toast Alert

    private var recordingSavedToast: some View {
        GlassCard {
            HStack(spacing: AppTheme.spacing.md) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                // Message
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording Saved!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("View in Recordings tab")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Dismiss button
                Button(action: {
                    withAnimation {
                        showRecordingSavedAlert = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppTheme.spacing.lg)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    // MARK: - Global Recording Controls

    private var globalRecordingControls: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacing.md) {
                // Status Header
                statusHeader

                // Sensor count when active
                if recordingCoordinator.state.isActive {
                    HStack(spacing: AppTheme.spacing.lg) {
                        StatPill(count: recordingCoordinator.activeSensorCount, label: "Sensors", color: .blue)
                        if recordingCoordinator.state.isRecording {
                            StatPill(count: recordingCoordinator.activeSensorCount, label: "Recording", color: .red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Control Buttons
                controlButtons
            }
            .padding(AppTheme.spacing.lg)
        }
    }

    private var statusHeader: some View {
        HStack {
            if recordingCoordinator.state.isRecording {
                PulsingDot(color: .red)
            }

            RecordingStatusBadge(state: recordingCoordinator.state)

            Spacer()

            if recordingCoordinator.state.isRecording {
                Text(formatDuration(currentDuration))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary.opacity(0.7))
                    .monospacedDigit()
            }
        }
    }

    private var currentDuration: TimeInterval {
        // Use currentTime to force SwiftUI to recalculate
        _ = currentTime
        return recordingCoordinator.sessionDuration
    }

    private var controlButtons: some View {
        HStack(spacing: AppTheme.spacing.sm) {
            startButton
            pauseButton
            stopButton
        }
        .sheet(isPresented: $showRecordingIdSheet) {
            RecordingIdEntrySheet(
                recordingId: $recordingIdInput,
                errorMessage: $recordingIdError,
                onCancel: {
                    recordingIdInput = ""
                    recordingIdError = nil
                    showRecordingIdSheet = false
                },
                onStart: { id in
                    let sensorList = polarManager.connectedSensors.map { (id: $0.id, name: $0.deviceName) }
                    recordingCoordinator.startRecording(sensors: sensorList, recordingId: id)
                    showRecordingIdSheet = false
                }
            )
        }
    }

    private var startButton: some View {
        let isPaused = recordingCoordinator.state.isPaused
        let title = isPaused ? "Resume All" : "Start All"
        let icon = isPaused ? "play.fill" : "record.circle"
        let disabled = recordingCoordinator.state.isRecording

        return GradientButton(
            title: title,
            icon: icon,
            gradient: greenGradient,
            isDisabled: disabled,
            isCompact: true
        ) {
            if isPaused {
                recordingCoordinator.resumeRecording()
            } else {
                recordingIdInput = ""
                recordingIdError = nil
                showRecordingIdSheet = true
            }
        }
    }

    private var pauseButton: some View {
        GradientButton(
            title: "Pause All",
            icon: "pause.fill",
            gradient: orangeGradient,
            isDisabled: !recordingCoordinator.state.isRecording,
            isCompact: true
        ) {
            recordingCoordinator.pauseRecording()
        }
    }

    private var stopButton: some View {
        let isIdle = !recordingCoordinator.state.isActive
        return GradientButton(
            title: "Stop All",
            icon: "stop.fill",
            gradient: redGradient,
            isDisabled: isIdle,
            isCompact: true
        ) {
            Task {
                await recordingCoordinator.stopRecording()
            }
        }
    }

    // Gradient helpers
    private var greenGradient: LinearGradient {
        LinearGradient(
            colors: [Color.green, Color.green.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var orangeGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange, Color.orange.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var redGradient: LinearGradient {
        LinearGradient(
            colors: [Color.red, Color.red.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Sensors Grid

    private var sensorsScrollView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppTheme.spacing.md),
                GridItem(.flexible(), spacing: AppTheme.spacing.md)
            ], spacing: AppTheme.spacing.md) {
                ForEach(polarManager.connectedSensors, id: \.id) { sensor in
                    NavigationLink(destination: SensorDetailView(sensor: sensor).id(sensor.id)) {
                        ModernSensorCard(sensor: sensor) {
                            polarManager.disconnect(deviceId: sensor.id)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)

                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 70))
                    .foregroundStyle(AppTheme.primaryGradient)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: AppTheme.spacing.sm) {
                GradientText("No Sensors Connected", font: .title2)

                Text("Connect your Polar H10 to start\nmonitoring heart rate variability")
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .background(.ultraThinMaterial)
        .cornerRadius(AppTheme.cornerRadius.md)
    }

    // MARK: - Add Sensor Button

    private var addSensorButton: some View {
        Button(action: {
            showDeviceList = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("Add Sensor")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.accentBlue)
            .cornerRadius(12)
            .shadow(color: AppTheme.accentBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(!polarManager.isBluetoothOn)
        .opacity(polarManager.isBluetoothOn ? 1.0 : 0.5)
        .scaleEffect(polarManager.isBluetoothOn ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: polarManager.isBluetoothOn)
    }

    // MARK: - Helper Functions

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Pill Component

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .cornerRadius(AppTheme.cornerRadius.full)
    }
}

// MARK: - Modern Sensor Card

struct ModernSensorCard: View {
    @ObservedObject var sensor: ConnectedSensor
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {
                // Header
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(sensor.displayId)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Heart Rate - Primary
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .symbolEffect(.pulse, options: .repeating, value: sensor.isActive)

                    Text("\(sensor.heartRate)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            sensor.isActive ?
                            LinearGradient(
                                colors: [Color.red, Color.pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        )
                        .contentTransition(.numericText())
                        .lineLimit(1)

                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.6))
                        .padding(.bottom, 4)
                        .lineLimit(1)
                }

                // Secondary Metrics
                HStack(spacing: AppTheme.spacing.sm) {
                    // Inline metrics with bullet separator
                    Text("\(sensor.rrInterval)ms • \(sensor.batteryLevel)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary.opacity(0.6))
                        .lineLimit(1)

                    Spacer()

                    // Tap indicator
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }
            .padding(AppTheme.spacing.md)
        }
        .overlay(
            sensor.isActive ?
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                .stroke(AppTheme.primaryGradient.opacity(0.3), lineWidth: 1)
            : nil
        )
        .shadow(color: sensor.isActive ? AppTheme.accentBlue.opacity(0.3) : .clear, radius: 12, x: 0, y: 6)
        .scaleEffect(sensor.isActive ? 1.0 : 0.98)
        .animation(.easeInOut(duration: 0.3), value: sensor.isActive)
    }

    private var statusColor: Color {
        switch sensor.connectionState {
        case .connected: return sensor.isActive ? .green : .yellow
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private func batteryIcon(for level: UInt) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        if level > 10 { return "battery.25" }
        return "battery.0"
    }

    private func batteryColor(for level: UInt) -> Color {
        level > 20 ? .green : .red
    }
}

// MARK: - Metric Chip

struct MetricChip: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.cornerRadius.sm)
    }
}

// MARK: - Device List View (Modern)

struct DeviceListView: View {
    @ObservedObject var polarManager: PolarManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.adaptiveBackground(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if polarManager.isScanning {
                        scanningBanner
                    }

                    if availableDevices.isEmpty && !polarManager.isScanning {
                        emptyDeviceState
                    } else {
                        deviceList
                    }
                }
            }
            .navigationTitle("Add Sensors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        polarManager.stopScanning()
                        isPresented = false
                    }
                    .foregroundColor(AppTheme.accentBlue)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if polarManager.isScanning {
                            polarManager.stopScanning()
                        } else {
                            polarManager.startScanning()
                        }
                    }) {
                        if polarManager.isScanning {
                            Text("Stop")
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .foregroundColor(AppTheme.accentBlue)
                }
            }
            .onAppear {
                polarManager.startScanning()
            }
            .onDisappear {
                polarManager.stopScanning()
            }
        }
    }

    private var scanningBanner: some View {
        HStack {
            ProgressView()
                .tint(AppTheme.accentBlue)
            Text("Scanning for sensors...")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacing.md) {
                ForEach(availableDevices, id: \.deviceId) { device in
                    ModernDeviceRow(device: device, isConnected: isDeviceConnected(device)) {
                        if isDeviceConnected(device) {
                            polarManager.disconnect(deviceId: device.deviceId)
                        } else {
                            polarManager.connect(to: device)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var emptyDeviceState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.primaryGradient)

            Text("No Devices Found")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Make sure your Polar H10 is nearby and powered on")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            GradientButton(title: "Scan Again", icon: "arrow.clockwise") {
                polarManager.startScanning()
            }
            .padding(.horizontal, 80)

            Spacer()
        }
    }

    private var availableDevices: [PolarDeviceInfo] {
        polarManager.discoveredDevices
    }

    private func isDeviceConnected(_ device: PolarDeviceInfo) -> Bool {
        polarManager.connectedSensors.contains { $0.id == device.deviceId }
    }
}

// MARK: - Modern Device Row

struct ModernDeviceRow: View {
    let device: PolarDeviceInfo
    let isConnected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack(spacing: AppTheme.spacing.md) {
                    deviceIcon
                    deviceInfo
                    Spacer()
                    statusIndicator
                }
                .padding(AppTheme.spacing.lg)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var deviceIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundFill)
                .frame(width: 50, height: 50)

            Image(systemName: iconSystemName)
                .font(.title3)
                .foregroundStyle(iconForegroundGradient)
        }
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(device.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(device.deviceId)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.6))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isConnected {
            Text("Connected")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(connectedBackgroundGradient)
                .cornerRadius(AppTheme.cornerRadius.full)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.primaryGradient)
        }
    }

    // Computed properties to simplify type checking
    private var iconBackgroundFill: AnyShapeStyle {
        if isConnected {
            return AnyShapeStyle(AppTheme.primaryGradient.opacity(0.2))
        } else {
            return AnyShapeStyle(AppTheme.glassMaterial)
        }
    }

    private var iconSystemName: String {
        isConnected ? "checkmark.circle.fill" : "sensor.tag.radiowaves.forward.fill"
    }

    private var iconForegroundGradient: AnyShapeStyle {
        if isConnected {
            return AnyShapeStyle(AppTheme.primaryGradient)
        } else {
            return AnyShapeStyle(AppTheme.primaryGradient)
        }
    }

    private var connectedBackgroundGradient: AnyShapeStyle {
        AnyShapeStyle(AppTheme.primaryGradient.opacity(0.3))
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .preferredColorScheme(.dark)
    }
}
