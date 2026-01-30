import SwiftUI

// MARK: - Design Tokens
// Premium Media Vault aesthetic: Deep cinematic blacks, warm amber projection accents,
// purple luminosity for premium content (HDR, Atmos)

enum VaultColors {
    // Core surfaces - whisper-quiet elevation changes
    static let vault = Color(red: 0.06, green: 0.06, blue: 0.08)           // Deepest background
    static let screen = Color(red: 0.09, green: 0.09, blue: 0.11)          // Card surfaces
    static let screenElevated = Color(red: 0.11, green: 0.11, blue: 0.14)  // Elevated cards
    static let screenHover = Color(red: 0.13, green: 0.13, blue: 0.16)     // Hover states

    // Borders - barely visible structure
    static let border = Color.white.opacity(0.06)
    static let borderSubtle = Color.white.opacity(0.04)
    static let borderFocus = Color.white.opacity(0.12)

    // Text hierarchy - warm celluloid tones
    static let celluloid = Color(red: 0.95, green: 0.93, blue: 0.88)       // Primary text (warm white)
    static let celluloidMuted = Color(red: 0.65, green: 0.62, blue: 0.58)  // Secondary text
    static let celluloidFaint = Color(red: 0.45, green: 0.42, blue: 0.40)  // Tertiary text

    // Accent - projection amber
    static let projection = Color(red: 1.0, green: 0.76, blue: 0.30)       // Primary amber accent
    static let projectionMuted = Color(red: 1.0, green: 0.76, blue: 0.30).opacity(0.7)
    static let projectionGlow = Color(red: 1.0, green: 0.76, blue: 0.30).opacity(0.15)

    // Premium content indicators - luminous quality
    static let dolby = Color(red: 0.68, green: 0.45, blue: 0.98)           // Dolby Vision purple
    static let dolbyGlow = Color(red: 0.68, green: 0.45, blue: 0.98).opacity(0.20)
    static let atmos = Color(red: 0.35, green: 0.75, blue: 0.95)           // Spatial audio blue
    static let atmosGlow = Color(red: 0.35, green: 0.75, blue: 0.95).opacity(0.20)
    static let hdr = Color(red: 1.0, green: 0.65, blue: 0.25)              // HDR10 warm orange
    static let hdrGlow = Color(red: 1.0, green: 0.65, blue: 0.25).opacity(0.20)

    // Semantic colors
    static let success = Color(red: 0.35, green: 0.78, blue: 0.55)
    static let warning = Color(red: 0.95, green: 0.70, blue: 0.30)
    static let destructive = Color(red: 0.92, green: 0.35, blue: 0.35)

    // Chart palette - film-inspired
    static let chartPurple = Color(red: 0.68, green: 0.45, blue: 0.98)
    static let chartBlue = Color(red: 0.35, green: 0.60, blue: 0.95)
    static let chartCyan = Color(red: 0.35, green: 0.75, blue: 0.85)
    static let chartGreen = Color(red: 0.45, green: 0.78, blue: 0.55)
    static let chartAmber = Color(red: 1.0, green: 0.76, blue: 0.30)
    static let chartOrange = Color(red: 1.0, green: 0.55, blue: 0.30)
    static let chartPink = Color(red: 0.95, green: 0.50, blue: 0.65)
    static let chartGray = Color(red: 0.50, green: 0.48, blue: 0.46)
}

// MARK: - Spacing System
enum VaultSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Typography
enum VaultTypography {
    static let displayLarge = Font.system(size: 42, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 32, weight: .semibold, design: .default)
    static let headline = Font.system(size: 18, weight: .semibold, design: .default)
    static let title = Font.system(size: 15, weight: .semibold, design: .default)
    static let body = Font.system(size: 13, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)
    static let micro = Font.system(size: 10, weight: .medium, design: .default)
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Corner Radius
enum VaultRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

// MARK: - Reusable Components

/// A card container with the vault aesthetic
struct VaultCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(padding: CGFloat = VaultSpacing.lg, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(VaultColors.screen)
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous)
                    .stroke(VaultColors.border, lineWidth: 1)
            )
    }
}

/// A hero metric display with optional glow for premium content
struct VaultMetric: View {
    let value: String
    let label: String
    let icon: String
    var glowColor: Color? = nil
    var valueColor: Color = VaultColors.celluloid

    var body: some View {
        VaultCard {
            VStack(alignment: .leading, spacing: VaultSpacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(glowColor ?? VaultColors.celluloidMuted)
                    Spacer()
                }

                Text(value)
                    .font(VaultTypography.displayMedium)
                    .foregroundColor(valueColor)
                    .monospacedDigit()
                    .shadow(color: glowColor?.opacity(0.5) ?? .clear, radius: 8, x: 0, y: 0)

                Text(label)
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }
        }
        .background(
            glowColor.map { color in
                RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous)
                    .fill(color.opacity(0.08))
            }
        )
    }
}

/// Badge component with luminous quality indicators
struct VaultBadge: View {
    let text: String
    let color: Color
    var glow: Bool = false
    var size: BadgeSize = .regular

    enum BadgeSize {
        case small, regular

        var font: Font {
            switch self {
            case .small: return VaultTypography.micro
            case .regular: return VaultTypography.captionMedium
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return VaultSpacing.xs
            case .regular: return VaultSpacing.sm
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return VaultSpacing.xxs
            case .regular: return VaultSpacing.xs
            }
        }
    }

    var body: some View {
        Text(text)
            .font(size.font)
            .foregroundColor(color)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: glow ? color.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
    }
}

/// Button styles
struct VaultPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaultTypography.bodyMedium)
            .foregroundColor(VaultColors.vault)
            .padding(.horizontal, VaultSpacing.lg)
            .padding(.vertical, VaultSpacing.sm)
            .background(
                isEnabled ? VaultColors.projection : VaultColors.celluloidMuted
            )
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .shadow(color: isEnabled ? VaultColors.projectionGlow : .clear, radius: 8, x: 0, y: 2)
    }
}

struct VaultSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaultTypography.bodyMedium)
            .foregroundColor(VaultColors.celluloid)
            .padding(.horizontal, VaultSpacing.lg)
            .padding(.vertical, VaultSpacing.sm)
            .background(VaultColors.screenElevated)
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                    .stroke(VaultColors.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct VaultGhostButton: ButtonStyle {
    var color: Color = VaultColors.celluloidMuted

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaultTypography.bodyMedium)
            .foregroundColor(color)
            .padding(.horizontal, VaultSpacing.md)
            .padding(.vertical, VaultSpacing.xs)
            .background(configuration.isPressed ? VaultColors.screenHover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: VaultRadius.sm, style: .continuous))
    }
}

/// Search field with vault styling
struct VaultSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: VaultSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VaultColors.celluloidFaint)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(VaultTypography.body)
                .foregroundColor(VaultColors.celluloid)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    onSubmit?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(VaultColors.celluloidFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, VaultSpacing.md)
        .padding(.vertical, VaultSpacing.sm)
        .background(VaultColors.screen)
        .clipShape(RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VaultRadius.md, style: .continuous)
                .stroke(VaultColors.border, lineWidth: 1)
        )
    }
}

/// Progress ring with cinematic styling
struct VaultProgressRing: View {
    let progress: Double
    var size: CGFloat = 64
    var lineWidth: CGFloat = 4
    var color: Color = VaultColors.projection

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(VaultColors.border, lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: size, height: size)
    }
}

/// Empty state view
struct VaultEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: VaultSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(VaultColors.celluloidFaint)

            VStack(spacing: VaultSpacing.xs) {
                Text(title)
                    .font(VaultTypography.headline)
                    .foregroundColor(VaultColors.celluloid)

                Text(subtitle)
                    .font(VaultTypography.body)
                    .foregroundColor(VaultColors.celluloidMuted)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(VaultPrimaryButton())
                    .padding(.top, VaultSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Section header
struct VaultSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: VaultSpacing.xxs) {
            Text(title)
                .font(VaultTypography.headline)
                .foregroundColor(VaultColors.celluloid)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(VaultTypography.caption)
                    .foregroundColor(VaultColors.celluloidMuted)
            }
        }
    }
}

/// Filter chip with vault styling
struct VaultFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(VaultTypography.captionMedium)
                .foregroundColor(isSelected ? VaultColors.vault : VaultColors.celluloid)
                .padding(.horizontal, VaultSpacing.md)
                .padding(.vertical, VaultSpacing.xs + 2)
                .background(isSelected ? VaultColors.projection : VaultColors.screen)
                .clipShape(RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VaultRadius.lg, style: .continuous)
                        .stroke(isSelected ? .clear : VaultColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Divider with vault styling
struct VaultDivider: View {
    var body: some View {
        Rectangle()
            .fill(VaultColors.border)
            .frame(height: 1)
    }
}

// MARK: - View Modifiers

struct VaultBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VaultColors.vault)
    }
}

extension View {
    func vaultBackground() -> some View {
        modifier(VaultBackground())
    }
}
