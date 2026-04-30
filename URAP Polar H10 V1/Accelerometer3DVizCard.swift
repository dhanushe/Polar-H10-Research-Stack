//
//  Accelerometer3DVizCard.swift
//  URAP Polar H10 V1
//
//  Collapsible 3D visualization of raw accelerometer vectors for a single sensor.
//  Lives inside SensorDetailView so each sensor gets its own card.
//  Shows the current acceleration vector in a rotatable 3D coordinate system with
//  a fading motion trail. Raw (unfiltered) values are used for display; the
//  filtered 1-second averages are what get recorded to session data.
//

import SwiftUI
import Combine

struct Accelerometer3DVizCard: View {

    @ObservedObject var sensor: ConnectedSensor

    @State private var isExpanded = true
    @State private var baseYaw: Double = 0.55
    @State private var dragDeltaYaw: Double = 0
    @State private var isAutoRotating = true
    @State private var hasInteracted = false

    private let pitch: Double = 0.32
    private let normFactor: Double = 2200.0   // mG — ±2200 mG fills the view
    private let rotationTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    private var effectiveYaw: Double { baseYaw + dragDeltaYaw }

    private var hasData: Bool {
        sensor.accX != 0 || sensor.accY != 0 || sensor.accZ != 0 || !sensor.accVectorHistory.isEmpty
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                header

                if isExpanded {
                    Divider()
                        .padding(.horizontal, AppTheme.spacing.lg)
                        .padding(.top, 2)

                    if hasData {
                        canvas3D
                            .frame(height: 270)
                            .padding(.horizontal, AppTheme.spacing.sm)
                            .padding(.top, AppTheme.spacing.xs)

                        axisReadouts
                            .padding(AppTheme.spacing.lg)
                    } else {
                        waitingView
                            .frame(height: 200)
                    }
                }
            }
        }
        .onReceive(rotationTimer) { _ in
            guard isExpanded, isAutoRotating else { return }
            baseYaw += 0.005
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: AppTheme.spacing.sm) {
                Image(systemName: "rotate.3d")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("3D Movement")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Raw accelerometer · drag to rotate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if sensor.currentAccMagnitude > 1 {
                    Text(String(format: "%.0f mG", sensor.currentAccMagnitude))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(AppTheme.cornerRadius.sm)
                }

                if isExpanded {
                    Button {
                        withAnimation { isAutoRotating.toggle() }
                    } label: {
                        Image(systemName: isAutoRotating ? "arrow.triangle.2.circlepath" : "pause.circle")
                            .font(.subheadline)
                            .foregroundColor(isAutoRotating ? .orange : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(AppTheme.spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Waiting View

    private var waitingView: some View {
        VStack(spacing: AppTheme.spacing.md) {
            Image(systemName: "gyroscope")
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Waiting for accelerometer data…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 3D Canvas

    private var canvas3D: some View {
        let capturedYaw = effectiveYaw
        let capturedPitch = pitch
        let capturedNorm = normFactor
        let history = sensor.accVectorHistory
        let curX = sensor.accX
        let curY = sensor.accY
        let curZ = sensor.accZ

        return Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.54)
            let scale = min(size.width, size.height) * 0.38

            // Isometric projection: rotate world Y (yaw) then X (pitch)
            let proj: (Double, Double, Double) -> CGPoint = { x, y, z in
                let rx = x * cos(capturedYaw) - z * sin(capturedYaw)
                let rz = x * sin(capturedYaw) + z * cos(capturedYaw)
                let finalX = rx
                let finalY = y * cos(capturedPitch) + rz * sin(capturedPitch)
                return CGPoint(
                    x: center.x + finalX * scale / capturedNorm,
                    y: center.y - finalY * scale / capturedNorm
                )
            }

            let origin = proj(0, 0, 0)
            let axLen = capturedNorm * 0.9

            // ── Floor grid (XZ plane) ────────────────────────────────────
            let gridColor = Color.white.opacity(0.055)
            for i in -3...3 {
                let t = Double(i) * axLen / 3.0
                var p1 = Path(); p1.move(to: proj(t, 0, -axLen)); p1.addLine(to: proj(t, 0, axLen))
                var p2 = Path(); p2.move(to: proj(-axLen, 0, t)); p2.addLine(to: proj(axLen, 0, t))
                ctx.stroke(p1, with: .color(gridColor), lineWidth: 0.5)
                ctx.stroke(p2, with: .color(gridColor), lineWidth: 0.5)
            }

            // ── Negative axis stubs (dashed) ─────────────────────────────
            let dashStyle = StrokeStyle(lineWidth: 1, dash: [4, 5])
            var nx = Path(); nx.move(to: origin); nx.addLine(to: proj(-axLen, 0, 0))
            var ny = Path(); ny.move(to: origin); ny.addLine(to: proj(0, -axLen, 0))
            var nz = Path(); nz.move(to: origin); nz.addLine(to: proj(0, 0, -axLen))
            ctx.stroke(nx, with: .color(.red.opacity(0.2)),   style: dashStyle)
            ctx.stroke(ny, with: .color(.green.opacity(0.2)), style: dashStyle)
            ctx.stroke(nz, with: .color(.blue.opacity(0.2)),  style: dashStyle)

            // ── Motion trail ─────────────────────────────────────────────
            if history.count > 1 {
                for i in 1..<history.count {
                    let frac = Double(i) / Double(history.count)
                    guard frac > 0.15 else { continue }
                    let p0 = proj(history[i-1].x, history[i-1].y, history[i-1].z)
                    let p1 = proj(history[i].x,   history[i].y,   history[i].z)
                    var seg = Path(); seg.move(to: p0); seg.addLine(to: p1)
                    ctx.stroke(seg, with: .color(Color.orange.opacity(frac * 0.55)),
                               lineWidth: frac * 1.8 + 0.4)
                }
                for i in (history.count / 2)..<history.count {
                    let frac = Double(i) / Double(history.count)
                    let pt = proj(history[i].x, history[i].y, history[i].z)
                    let r = frac * 3.0
                    ctx.fill(Circle().path(in: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)),
                             with: .color(Color.orange.opacity(frac * 0.6)))
                }
            }

            // ── Positive axes ────────────────────────────────────────────
            var px = Path(); px.move(to: origin); px.addLine(to: proj(axLen, 0, 0))
            var py = Path(); py.move(to: origin); py.addLine(to: proj(0, axLen, 0))
            var pz = Path(); pz.move(to: origin); pz.addLine(to: proj(0, 0, axLen))
            ctx.stroke(px, with: .color(.red.opacity(0.85)),   lineWidth: 1.8)
            ctx.stroke(py, with: .color(.green.opacity(0.85)), lineWidth: 1.8)
            ctx.stroke(pz, with: .color(.blue.opacity(0.85)),  lineWidth: 1.8)

            // Arrowheads
            let arrowSize: Double = 5
            for (tipWorld, color): ((Double, Double, Double), Color) in [
                ((axLen, 0, 0), .red), ((0, axLen, 0), .green), ((0, 0, axLen), .blue)
            ] {
                let tip = proj(tipWorld.0, tipWorld.1, tipWorld.2)
                let base = proj(tipWorld.0 * 0.88, tipWorld.1 * 0.88, tipWorld.2 * 0.88)
                let dx = tip.x - base.x; let dy = tip.y - base.y
                let len = sqrt(dx*dx + dy*dy)
                guard len > 0.001 else { continue }
                let ux = dx/len; let uy = dy/len
                let perp = CGPoint(x: -uy * arrowSize * 0.4, y: ux * arrowSize * 0.4)
                var arrow = Path()
                arrow.move(to: tip)
                arrow.addLine(to: CGPoint(x: base.x + perp.x, y: base.y + perp.y))
                arrow.addLine(to: CGPoint(x: base.x - perp.x, y: base.y - perp.y))
                arrow.closeSubpath()
                ctx.fill(arrow, with: .color(color.opacity(0.9)))
            }

            // Axis labels
            ctx.draw(Text("X").font(.caption2).bold().foregroundStyle(Color.red),
                     at: proj(axLen * 1.18, 0, 0))
            ctx.draw(Text("Y").font(.caption2).bold().foregroundStyle(Color.green),
                     at: proj(0, axLen * 1.18, 0))
            ctx.draw(Text("Z").font(.caption2).bold().foregroundStyle(Color.blue),
                     at: proj(0, 0, axLen * 1.18))

            // ── Origin dot ───────────────────────────────────────────────
            let or2: Double = 3
            ctx.fill(Circle().path(in: CGRect(x: origin.x-or2, y: origin.y-or2,
                                              width: or2*2, height: or2*2)),
                     with: .color(.white.opacity(0.5)))

            // ── Dashed line to current vector ────────────────────────────
            let curPt = proj(curX, curY, curZ)
            var vecLine = Path(); vecLine.move(to: origin); vecLine.addLine(to: curPt)
            ctx.stroke(vecLine, with: .color(.orange.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

            // ── Current vector dot with glow ─────────────────────────────
            for (r, alpha): (Double, Double) in [(22, 0.07), (14, 0.13), (8, 0.25)] {
                ctx.fill(Circle().path(in: CGRect(x: curPt.x-r, y: curPt.y-r,
                                                  width: r*2, height: r*2)),
                         with: .color(Color.orange.opacity(alpha)))
            }
            let cr: Double = 5.5
            ctx.fill(Circle().path(in: CGRect(x: curPt.x-cr, y: curPt.y-cr,
                                              width: cr*2, height: cr*2)),
                     with: .color(.orange))
            let cr2: Double = 2.5
            ctx.fill(Circle().path(in: CGRect(x: curPt.x-cr2, y: curPt.y-cr2,
                                              width: cr2*2, height: cr2*2)),
                     with: .color(.white.opacity(0.8)))
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    isAutoRotating = false
                    hasInteracted = true
                    dragDeltaYaw = Double(value.translation.width) / 120.0
                }
                .onEnded { value in
                    baseYaw += Double(value.translation.width) / 120.0
                    dragDeltaYaw = 0
                }
        )
        .overlay(alignment: .bottomTrailing) {
            if !hasInteracted {
                Label("Drag to rotate", systemImage: "hand.draw")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(6)
            }
        }
    }

    // MARK: - Axis Readouts

    private var axisReadouts: some View {
        HStack {
            axisLabel("X", value: sensor.accX, color: .red)
            Spacer()
            axisLabel("Y", value: sensor.accY, color: .green)
            Spacer()
            axisLabel("Z", value: sensor.accZ, color: .blue)
            Spacer()
            Divider().frame(height: 30)
            Spacer()
            axisLabel("|v|", value: sensor.currentAccMagnitude, color: .orange, signed: false)
        }
    }

    private func axisLabel(_ name: String, value: Double, color: Color, signed: Bool = true) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(signed ? String(format: "%+.0f", value) : String(format: "%.0f", value))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            Text("mG")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
