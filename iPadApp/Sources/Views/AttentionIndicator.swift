// AttentionIndicator.swift
// iPad Trackpad Controller - Visual Attention Alert
// iOS 18+ / iPadOS 18+

import SwiftUI

/// Pulsing attention indicator that appears when Claude needs input
struct AttentionIndicator: View {
    let isActive: Bool

    @State private var isPulsing = false
    @State private var sparklePhase: Double = 0

    var body: some View {
        if isActive {
            ZStack {
                // Base glow
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(isPulsing ? 0.4 : 0.2),
                                Color.red.opacity(isPulsing ? 0.3 : 0.1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)

                // Sparkle overlay
                SparkleEffect(phase: sparklePhase)
                    .opacity(0.6)
            }
            .onAppear {
                isPulsing = true
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    sparklePhase = 1
                }
            }
            .onDisappear {
                isPulsing = false
                sparklePhase = 0
            }
        }
    }
}

/// Animated sparkle effect
struct SparkleEffect: View {
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let sparkleCount = 8

                for i in 0..<sparkleCount {
                    let progress = (phase + Double(i) / Double(sparkleCount)).truncatingRemainder(dividingBy: 1.0)
                    let x = progress * size.width
                    let y = size.height * 0.5 + sin(progress * .pi * 4) * 3

                    let opacity = sin(progress * .pi) * 0.8
                    let sparkleSize = 2.0 + sin(progress * .pi) * 2

                    let rect = CGRect(
                        x: x - sparkleSize / 2,
                        y: y - sparkleSize / 2,
                        width: sparkleSize,
                        height: sparkleSize
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

/// Notification badge for macro bar toggle
struct AttentionBadge: View {
    let isActive: Bool

    @State private var scale: CGFloat = 1.0

    var body: some View {
        if isActive {
            Circle()
                .fill(Color.orange)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        scale = 1.2
                    }
                }
                .onDisappear {
                    scale = 1.0
                }
        }
    }
}

// MARK: - View Modifier

struct AttentionModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.background(AttentionIndicator(isActive: isActive))
    }
}

extension View {
    func attentionIndicator(_ isActive: Bool) -> some View {
        modifier(AttentionModifier(isActive: isActive))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Status bar with attention
        HStack {
            Text("Status Bar")
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
        .background(
            ZStack {
                Color(white: 0.1)
                AttentionIndicator(isActive: true)
            }
        )
        .frame(height: 44)

        // Badge preview
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.25))
                .frame(width: 60, height: 44)

            AttentionBadge(isActive: true)
                .offset(x: 4, y: -4)
        }
    }
    .padding()
    .background(Color(white: 0.15))
}
