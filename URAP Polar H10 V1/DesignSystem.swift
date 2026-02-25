//
//  DesignSystem.swift
//  URAP Polar H10 V1
//
//  Monochrome Premium design system with professional aesthetics
//

import SwiftUI

// MARK: - Theme Colors

struct AppTheme {

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "0A84FF"), Color(hex: "0A84FF").opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let secondaryGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "0A84FF"), Color(hex: "0A84FF").opacity(0.6)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Adaptive background gradient that works in both light and dark mode
    static let darkGradient = LinearGradient(
        colors: [Color(hex: "2C2C2E"), Color(hex: "1C1C1E")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let lightGradient = LinearGradient(
        colors: [Color(hex: "F2F2F7"), Color(hex: "E5E5EA")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Solid Colors

    // iOS System Blue - Primary Accent
    static let accentBlue = Color(hex: "0A84FF")

    // Semantic Colors
    static let successGreen = Color(hex: "30D158")
    static let warningOrange = Color(hex: "FF9F0A")
    static let errorRed = Color(hex: "FF453A")

    // Backgrounds - Dark Mode
    static let darkBackground = Color(hex: "1C1C1E")
    static let darkCardBackground = Color(hex: "2C2C2E")
    static let darkElevatedBackground = Color(hex: "3A3A3C")

    // Backgrounds - Light Mode
    static let lightBackground = Color(hex: "F2F2F7")
    static let lightCardBackground = Color(hex: "FFFFFF")
    static let lightElevatedBackground = Color(hex: "E5E5EA")

    // Dynamic Backgrounds (will adapt to color scheme)
    static let cardBackground = Color(hex: "2C2C2E").opacity(0.9)
    static let glassMaterial = Color.white.opacity(0.05)

    // MARK: - Spacing

    static let spacing = Spacing()

    struct Spacing {
        let xs: CGFloat = 4
        let sm: CGFloat = 8
        let md: CGFloat = 16
        let lg: CGFloat = 24
        let xl: CGFloat = 32
        let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    static let cornerRadius = CornerRadius()

    struct CornerRadius {
        let sm: CGFloat = 8
        let md: CGFloat = 12
        let lg: CGFloat = 16
        let xl: CGFloat = 24
        let full: CGFloat = 999
    }

    // MARK: - Shadows

    static func glowShadow(color: Color = .blue, radius: CGFloat = 12) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 4)
            .shadow(color: color.opacity(0.2), radius: radius * 2, x: 0, y: 8)
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

    // MARK: - Adaptive Gradients and Backgrounds

    /// Returns the appropriate background gradient based on color scheme
    static func adaptiveBackground(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark ? darkGradient : lightGradient
    }

    /// Returns the appropriate card background color with proper opacity
    static func adaptiveCardBackground(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "2C2C2E").opacity(0.9)
        } else {
            return Color(hex: "FFFFFF").opacity(0.95)
        }
    }

    /// Returns the appropriate glass material color
    static func adaptiveGlassMaterial(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.05)
        } else {
            return Color.black.opacity(0.03)
        }
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
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) var colorScheme

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                        .fill(AppTheme.adaptiveCardBackground(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg)
                                .stroke(strokeColor, lineWidth: 1)
                        )
                        .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
                }
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius.lg))
    }

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
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
            .foregroundColor(textColor)
            .padding(.horizontal, isCompact ? 12 : 20)
            .padding(.vertical, isCompact ? 8 : 12)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isDisabled {
                        Color.gray.opacity(0.3)
                    } else {
                        gradient
                    }
                }
            )
            .cornerRadius(AppTheme.cornerRadius.md)
            .shadow(color: isDisabled ? .clear : AppTheme.accentBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled)
        .scaleEffect(isDisabled ? 0.95 : 1.0)
        .opacity(isDisabled ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }

    /// Adaptive text color for better contrast in both light and dark modes
    private var textColor: Color {
        // In light mode, use very dark text for better contrast on colored gradients
        // In dark mode, keep white text
        colorScheme == .dark ? .white : Color(red: 0.1, green: 0.1, blue: 0.1)
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
                .foregroundColor(.primary.opacity(0.7))
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
        .cornerRadius(AppTheme.cornerRadius.full)
        .shadow(color: backgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var backgroundColor: Color {
        if state.isRecording { return .red }
        if state.isPaused { return .orange }
        if state.isSaving { return .blue }
        return .gray
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 16, height: 16)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 1)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
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
                    .foregroundColor(.primary.opacity(0.6))
                    .frame(width: 16)
            }

            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
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
