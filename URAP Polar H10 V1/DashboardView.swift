//
//  DashboardView.swift
//  URAP Polar H10 V1
//
//  Ultra-modern dashboard with live sensor cards and global recording controls
//

import SwiftUI
import Charts
import Combine
import PolarBleSdk

struct DashboardView: View {
    @StateObject private var polarManager = PolarManager.shared
    @StateObject private var recordingCoordinator = RecordingCoordinator.shared
    @State private var showDeviceList = false
    @State private var currentTime = Date()
    @State private var showRecordingSavedAlert = false
    @State private var showRecordingIdSheet = false
    @State private var recordingIdInput: String = ""
    @State private var recordingIdError: String?
    @State private var headerAppeared = false
    @Environment(\.colorScheme) var colorScheme

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppTheme.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            // Subtle radial glow behind content in dark mode
            if colorScheme == .dark {
                RadialGradient(
                    colors: [AppTheme.neonBlue.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if !polarManager.connectedSensors.isEmpty {
                    globalRecordingControls
                        .padding(.horizontal, AppTheme.spacing.md)
                        .padding(.top, AppTheme.spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if polarManager.connectedSensors.isEmpty {
                    emptyState
                } else {
                    sensorsScrollView
                }

                if let error = polarManager.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, AppTheme.spacing.md)
                        .padding(.bottom, AppTheme.spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: polarManager.connectedSensors.isEmpty)

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton(
                        title: "Add Sensor",
                        icon: "plus.circle.fill",
                        action: { showDeviceList = true },
                        isEnabled: polarManager.isBluetoothOn
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacing.lg)
            .padding(.bottom, 96)

            // Toast overlay
            VStack {
                Spacer()
                if showRecordingSavedAlert {
                    recordingSavedToast
                        .padding(.horizontal, AppTheme.spacing.lg)
                        .padding(.bottom, 100)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showRecordingSavedAlert = false
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showRecordingSavedAlert = false
                            }
                        }
                }
            }
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
            if case .saving = oldState, case .idle = newState {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showRecordingSavedAlert = true
                }
            }
        }
    }

    // MARK: - Toast

    private var recordingSavedToast: some View {
        GlassCard(accentColor: AppTheme.neonGreen) {
            HStack(spacing: AppTheme.spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.emeraldGradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Recording Saved")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("View it in the Recordings tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: {
                    withAnimation { showRecordingSavedAlert = false }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppTheme.spacing.lg)
        }
        .shadow(color: AppTheme.neonGreen.opacity(0.3), radius: 24, x: 0, y: 12)
    }

    // MARK: - Global Recording Controls

    private var globalRecordingControls: some View {
        let isRecording = recordingCoordinator.state.isRecording
        let isPaused = recordingCoordinator.state.isPaused

        return GlassCard(accentColor: isRecording ? AppTheme.neonRed : (isPaused ? AppTheme.neonOrange : nil)) {
            VStack(spacing: AppTheme.spacing.md) {
                recordingStatusRow

                if recordingCoordinator.state.isActive {
                    sensorCountRow
                }

                controlButtonRow
            }
            .padding(AppTheme.spacing.lg)
        }
        .shadow(
            color: isRecording ? AppTheme.neonRed.opacity(0.2) : .clear,
            radius: 20, x: 0, y: 8
        )
        .animation(.easeInOut(duration: 0.4), value: isRecording)
    }

    private var recordingStatusRow: some View {
        HStack {
            if recordingCoordinator.state.isRecording {
                PulsingDot(color: AppTheme.neonRed, size: 8)
                    .transition(.scale.combined(with: .opacity))
            }

            RecordingStatusBadge(state: recordingCoordinator.state)

            Spacer()

            if recordingCoordinator.state.isRecording {
                Text(formatDuration(currentDuration))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.heartGradient)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
    }

    private var sensorCountRow: some View {
        HStack(spacing: AppTheme.spacing.sm) {
            StatPill(count: recordingCoordinator.activeSensorCount, label: "Sensors", color: AppTheme.neonBlue)
            if recordingCoordinator.state.isRecording {
                StatPill(count: recordingCoordinator.activeSensorCount, label: "Recording", color: AppTheme.neonRed)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var controlButtonRow: some View {
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
        let title = isPaused ? "Resume" : "Start"
        let icon  = isPaused ? "play.fill" : "record.circle"
        let disabled = recordingCoordinator.state.isRecording

        return GradientButton(
            title: title, icon: icon,
            gradient: AppTheme.emeraldGradient,
            isDisabled: disabled, isCompact: true
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
            title: "Pause", icon: "pause.fill",
            gradient: AppTheme.sunriseGradient,
            isDisabled: !recordingCoordinator.state.isRecording,
            isCompact: true
        ) {
            recordingCoordinator.pauseRecording()
        }
    }

    private var stopButton: some View {
        GradientButton(
            title: "Stop", icon: "stop.fill",
            gradient: LinearGradient(colors: [AppTheme.neonRed, Color(hex: "C0392B")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing),
            isDisabled: !recordingCoordinator.state.isActive,
            isCompact: true
        ) {
            Task { await recordingCoordinator.stopRecording() }
        }
    }

    // MARK: - Sensors Grid

    private var sensorsScrollView: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppTheme.spacing.md),
                          GridItem(.flexible(), spacing: AppTheme.spacing.md)],
                spacing: AppTheme.spacing.md
            ) {
                ForEach(polarManager.connectedSensors, id: \.id) { sensor in
                    NavigationLink(destination: SensorDetailView(sensor: sensor).id(sensor.id)) {
                        ModernSensorCard(sensor: sensor) {
                            polarManager.disconnect(deviceId: sensor.id)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(AppTheme.spacing.md)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            ZStack {
                ForEach([0, 1, 2], id: \.self) { i in
                    Circle()
                        .stroke(AppTheme.neonBlue.opacity(0.06 - Double(i) * 0.015), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 50), height: CGFloat(120 + i * 50))
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.neonBlue.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            VStack(spacing: AppTheme.spacing.sm) {
                GradientText("No Sensors Connected", font: .title2)

                Text("Connect your Polar H10 to start\nmonitoring heart rate variability")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.bottom, 80)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppTheme.spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.neonOrange)
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(AppTheme.spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md)
                .stroke(AppTheme.neonOrange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var currentDuration: TimeInterval {
        _ = currentTime
        return recordingCoordinator.sessionDuration
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.8), radius: 3)

            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Modern Sensor Card

struct ModernSensorCard: View {
    @ObservedObject var sensor: ConnectedSensor
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var appeared = false

    private var recentHRData: [HeartRateDataPoint] {
        let cutoff = Date().addingTimeInterval(-60)
        return sensor.heartRateHistory.suffix(30).filter { $0.timestamp >= cutoff }
    }

    var body: some View {
        GlassCard(accentColor: sensor.isActive ? AppTheme.neonBlue.opacity(0.5) : nil) {
            VStack(alignment: .leading, spacing: AppTheme.spacing.sm) {

                // Header row
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: statusColor.opacity(0.9), radius: sensor.isActive ? 4 : 0)

                        Text(sensor.displayId)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Heart Rate Value
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(AppTheme.neonRed)
                        .symbolEffect(.pulse, options: .repeating, value: sensor.isActive)

                    Text("\(sensor.heartRate)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(
                            sensor.isActive
                                ? AnyShapeStyle(AppTheme.heartGradient)
                                : AnyShapeStyle(Color.primary.opacity(0.2))
                        )
                        .contentTransition(.numericText())
                        .lineLimit(1)

                    Text("BPM")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }

                // Mini sparkline chart
                if !recentHRData.isEmpty && sensor.isActive {
                    Chart(recentHRData) { dp in
                        LineMark(
                            x: .value("T", dp.timestamp),
                            y: .value("HR", dp.value)
                        )
                        .foregroundStyle(AppTheme.heartGradient)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("T", dp.timestamp),
                            y: .value("HR", dp.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.neonRed.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 36)
                    .transition(.opacity)
                }

                // Secondary metrics
                HStack {
                    Label("\(sensor.rrInterval)ms", systemImage: "waveform")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Label("\(sensor.batteryLevel)%", systemImage: batteryIcon(for: sensor.batteryLevel))
                        .font(.caption2)
                        .foregroundColor(batteryColor(for: sensor.batteryLevel))
                        .lineLimit(1)
                }
            }
            .padding(AppTheme.spacing.md)
        }
        .shadow(
            color: sensor.isActive ? AppTheme.neonBlue.opacity(0.18) : .clear,
            radius: 20, x: 0, y: 10
        )
        .scaleEffect(appeared ? 1.0 : 0.94)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var statusColor: Color {
        switch sensor.connectionState {
        case .connected:    return sensor.isActive ? AppTheme.neonGreen : Color.yellow
        case .connecting:   return AppTheme.neonOrange
        case .disconnected: return AppTheme.neonRed
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
        level > 20 ? AppTheme.neonGreen : AppTheme.neonRed
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
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerRadius.sm).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Device List View

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
                    .foregroundColor(AppTheme.neonBlue)
                    .fontWeight(.semibold)
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
                            Text("Stop").foregroundColor(AppTheme.neonRed)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(AppTheme.neonBlue)
                        }
                    }
                }
            }
            .onAppear { polarManager.startScanning() }
            .onDisappear { polarManager.stopScanning() }
        }
    }

    private var scanningBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.neonBlue)
                .scaleEffect(0.9)
            Text("Scanning for sensors...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacing.md)
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
            .padding(AppTheme.spacing.md)
        }
    }

    private var emptyDeviceState: some View {
        VStack(spacing: AppTheme.spacing.xl) {
            Spacer()

            NeonIconCircle(icon: "antenna.radiowaves.left.and.right.slash", gradient: AppTheme.primaryGradient, size: 72)

            VStack(spacing: AppTheme.spacing.sm) {
                Text("No Devices Found")
                    .font(.headline)
                Text("Make sure your Polar H10 is nearby and powered on")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            GradientButton(title: "Scan Again", icon: "arrow.clockwise") {
                polarManager.startScanning()
            }
            .padding(.horizontal, 80)

            Spacer()
        }
    }

    private var availableDevices: [PolarDeviceInfo] { polarManager.discoveredDevices }
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
            GlassCard(accentColor: isConnected ? AppTheme.neonGreen.opacity(0.5) : nil) {
                HStack(spacing: AppTheme.spacing.md) {
                    NeonIconCircle(
                        icon: isConnected ? "checkmark.circle.fill" : "sensor.tag.radiowaves.forward.fill",
                        gradient: isConnected ? AppTheme.emeraldGradient : AppTheme.primaryGradient,
                        size: 50
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(device.deviceId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isConnected {
                        Text("Connected")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.emeraldGradient)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                }
                .padding(AppTheme.spacing.lg)
            }
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Preview

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { DashboardView() }
            .preferredColorScheme(.dark)
    }
}
