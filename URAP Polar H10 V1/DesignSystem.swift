//
//  DesignSystem.swift
//  URAP Polar H10 V1
//
//  Ultra-modern design system — Biotech Premium Dark
//

import SwiftUI

// MARK: - Theme Colors

struct AppTheme {

    // MARK: - Core Accent Colors

    static let neonBlue   = Color(hex: "0A84FF")
    static let neonRed    = Color(hex: "FF2D55")
    static let neonCyan   = Color(hex: "32ADE6")
    static let neonPurple = Color(hex: "BF5AF2")
    static let neonGreen  = Color(hex: "30D158")
    static let neonOrange = Color(hex: "FF9F0A")
    static let neonPink   = Color(hex: "FF6B9D")

    // Legacy alias
    static let accentBlue   = neonBlue
    static let successGreen = neonGreen
    static let warningOrange = neonOrange
    static let errorRed     = neonRed

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [neonBlue, neonCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heartGradient = LinearGradient(
        colors: [neonRed, neonPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hrvGradient = LinearGradient(
        colors: [neonBlue, neonCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purpleGradient = LinearGradient(
        colors: [neonPurple, Color(hex: "9B59B6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emeraldGradient = LinearGradient(
        colors: [neonGreen, Color(hex: "00C896")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunriseGradient = LinearGradient(
        colors: [neonOrange, neonPink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let secondaryGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [neonBlue, neonCyan.opacity(0.6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Background Gradients

    static let darkGradient = LinearGradient(
        colors: [Color(hex: "0C0C16"), Color(hex: "0E0E1A")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let lightGradient = LinearGradient(
        colors: [Color(hex: "F0F2F8"), Color(hex: "E8EAF0")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Background Colors

    static let darkBackground         = Color(hex: "0C0C16")
    static let darkCardBackground     = Color(hex: "16161E")
    static let darkElevatedBackground = Color(hex: "1E1E28")

    static let lightBackground         = Color(hex: "F0F2F8")
    static let lightCardBackground     = Color(hex: "FFFFFF")
    static let lightElevatedBackground = Color(hex: "E8EAF0")

    static let cardBackground  = Color(hex: "16161E").opacity(0.9)
    static let glassMaterial   = Color.white.opacity(0.05)

    // MARK: - Spacing

    static let spacing = Spacing()

    struct Spacing {
        let xs: CGFloat  = 4
        let sm: CGFloat  = 8
        let md: CGFloat  = 16
        let lg: CGFloat  = 24
        let xl: CGFloat  = 32
        let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    static let cornerRadius = CornerRadius()

    struct CornerRadius {
        let sm: CGFloat   = 8
        let md: CGFloat   = 12
        let lg: CGFloat   = 18
        let xl: CGFloat   = 26
        let full: CGFloat = 999
    }

    // MARK: - Dynamic Color Helpers

    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkBackground : lightBackground
    }

    static func cardBackgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardBackground : lightCardBackground
    }

    static func elevatedBackgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkElevatedBackground : lightElevatedBackground
    }

    static func adaptiveBackground(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark ? darkGradient : lightGradient
    }

    static func adaptiveCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "16161E").opacity(0.9)
            : Color(hex: "FFFFFF").opacity(0.96)
    }

    static func adaptiveGlassMaterial(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    var accentColor: Color? = nil
    @Environment(\.colorScheme) var colorScheme

    init(accentColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                        .fill(AppTheme.adaptiveCardBackground(for: colorScheme))
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                        .stroke(borderGradient, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: 16, x: 0, y: 8)
                .shadow(color: glowColor, radius: 32, x: 0, y: 0)
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg))
    }

    private var borderGradient: LinearGradient {
        if let accent = accentColor {
            return LinearGradient(
                colors: [accent.opacity(0.6), accent.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return colorScheme == .dark
            ? LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color.black.opacity(0.08), Color.black.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.08)
    }

    private var glowColor: Color {
        guard let accent = accentColor else { return .clear }
        return accent.opacity(colorScheme == .dark ? 0.12 : 0.06)
    }
}

// MARK: - Gradient Button

struct GradientButton: View {
    let title: String
    let icon: String?
    let gradient: LinearGradient
    let action: () -> Void
    var isDisabled: Bool = false
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false

    init(
        title: String,
        icon: String? = nil,
        gradient: LinearGradient = AppTheme.primaryGradient,
        isDisabled: Bool = false,
        isCompact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.isDisabled = isDisabled
        self.isCompact = isCompact
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 4 : 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(isCompact ? .caption : .body)
                        .fontWeight(.semibold)
                }
                Text(title)
                    .font(isCompact ? .caption : .body)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundColor(isDisabled ? .white.opacity(0.4) : .white)
            .padding(.horizontal, isCompact ? 12 : 20)
            .padding(.vertical, isCompact ? 8 : 14)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isDisabled {
                        Color.white.opacity(0.08)
                    } else {
                        gradient
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius.md)
                    .stroke(Color.white.opacity(isDisabled ? 0.05 : 0.15), lineWidth: 1)
            )
            .shadow(color: isDisabled ? .clear : glowColor, radius: 12, x: 0, y: 6)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDisabled)
        .buttonStyle(ScalePressStyle())
    }

    private var glowColor: Color {
        // Extract approximate glow from gradient (use blue as fallback)
        AppTheme.neonBlue.opacity(0.35)
    }
}

// MARK: - Scale Press Button Style

struct ScalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Animated Metric View

struct AnimatedMetricView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var showPulse: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .symbolEffect(.pulse, options: .repeating, value: showPulse)

                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
            }
            .animation(.easeInOut(duration: 0.3), value: value)

            Text(label)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.6))
        }
    }
}

// MARK: - Gradient Text

struct GradientText: View {
    let text: String
    let gradient: LinearGradient
    let font: Font

    init(_ text: String, gradient: LinearGradient = AppTheme.primaryGradient, font: Font = .title) {
        self.text = text
        self.gradient = gradient
        self.font = font
    }

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(.bold)
            .foregroundStyle(gradient)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Recording Status Badge

struct RecordingStatusBadge: View {
    let state: RecordingLifecycleState
    @State private var glowing = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.icon)
                .font(.caption)
                .symbolEffect(.pulse, options: .repeating, value: state.isRecording)

            Text(state.displayText)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(backgroundColor.opacity(0.4), lineWidth: 1))
        .shadow(color: backgroundColor.opacity(glowing ? 0.7 : 0.3), radius: glowing ? 10 : 5, x: 0, y: 0)
        .onAppear {
            if state.isRecording {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
        }
        .onChange(of: state.isRecording) { _, isRecording in
            if isRecording {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            } else {
                glowing = false
            }
        }
    }

    private var backgroundColor: Color {
        if state.isRecording { return AppTheme.neonRed }
        if state.isPaused    { return AppTheme.neonOrange }
        if state.isSaving    { return AppTheme.neonBlue }
        return Color.gray.opacity(0.6)
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 8
    @State private var pulse1 = false
    @State private var pulse2 = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size * 3, height: size * 3)
                .scaleEffect(pulse1 ? 1.6 : 0.8)
                .opacity(pulse1 ? 0 : 0.6)

            Circle()
                .fill(color.opacity(0.25))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulse2 ? 1.4 : 0.9)
                .opacity(pulse2 ? 0 : 0.8)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse1 = true
            }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(0.4)) {
                pulse2 = true
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let icon: String?

    init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.5))
                    .frame(width: 16)
            }

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.6))
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Neon Icon Circle

struct NeonIconCircle: View {
    let icon: String
    let gradient: LinearGradient
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient.opacity(0.15))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(gradient.opacity(0.4), lineWidth: 1)
                )

            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isEnabled: Bool = true

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                AppTheme.primaryGradient
            )
            .clipShape(Capsule())
            .shadow(color: AppTheme.neonBlue.opacity(0.5), radius: 16, x: 0, y: 8)
            .shadow(color: AppTheme.neonBlue.opacity(0.2), radius: 32, x: 0, y: 16)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEnabled)
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Custom Tab Bar

struct CustomFloatingTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) var colorScheme

    private let tabs: [(icon: String, label: String)] = [
        ("chart.line.uptrend.xyaxis", "Dashboard"),
        ("folder.fill", "Recordings"),
        ("gear", "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                tabItem(index: index)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                                         Color.white.opacity(colorScheme == .dark ? 0.04 : 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 30, x: 0, y: 12)
        .padding(.horizontal, 36)
    }

    private func tabItem(index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: tabs[index].icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(AppTheme.primaryGradient) : AnyShapeStyle(Color.secondary.opacity(0.6)))
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(tabs[index].label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppTheme.neonBlue : .secondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.neonBlue.opacity(colorScheme == .dark ? 0.12 : 0.08))
                            .padding(.horizontal, 4)
                    }
                }
            )
        }
        .buttonStyle(ScalePressStyle())
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}
