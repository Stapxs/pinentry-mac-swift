import AppKit
import SwiftUI

@MainActor
struct PrototypeWindowView: View {
    @StateObject private var coordinator: WindowPresentationCoordinator

    init(coordinator: WindowPresentationCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    init() {
        _coordinator = StateObject(wrappedValue: WindowPresentationCoordinator(
            previewDialog: PreviewDialogs.minimalPassphrase
        ))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if let viewModel = coordinator.activeViewModel {
                DialogCardView(viewModel: viewModel)
                    .padding(36)
            } else {
                EmptyCardPlaceholder()
                    .padding(36)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(nsColor: NSColor(calibratedWhite: 0.96, alpha: 1.0)),
                Color(nsColor: NSColor(calibratedWhite: 0.88, alpha: 1.0))
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: 70, y: -80)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.black.opacity(0.05))
                .frame(width: 260, height: 200)
                .rotationEffect(.degrees(18))
                .offset(x: -90, y: 70)
        }
        .ignoresSafeArea()
    }
}

struct DialogCardView: View {
    @ObservedObject var viewModel: DialogViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case passphrase
        case repeatedPassphrase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            if viewModel.state.showsErrorSection {
                errorSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if viewModel.dialog.mode == .passphrase {
                passphraseSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            buttonsSection
        }
        .padding(28)
        .frame(maxWidth: 460)
        .background(cardBackground)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state.isExpanded)
        .onAppear {
            focusedField = viewModel.dialog.mode == .passphrase ? .passphrase : nil
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            viewModel.resolveIcon()
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .foregroundStyle(iconForegroundStyle)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.dialog.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.dialog.message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let keyboardPrompt = viewModel.keyboardPrompt {
                    Text(keyboardPrompt)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.95))
                }
            }
        }
    }

    private var errorSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(viewModel.dialog.errorText ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.red.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.14), lineWidth: 1)
        )
    }

    private var passphraseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            passwordField(
                placeholder: viewModel.promptText,
                text: $viewModel.passphrase,
                field: .passphrase
            )

            if viewModel.state.showsRepeatField {
                passwordField(
                    placeholder: viewModel.confirmPromptText,
                    text: $viewModel.repeatedPassphrase,
                    field: .repeatedPassphrase
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let mismatchHint = viewModel.mismatchHint {
                Text(mismatchHint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.88))
                    .transition(.opacity)
            }

            if viewModel.state.showsQualityBar, let assessment = viewModel.qualityAssessment {
                qualitySection(assessment: assessment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if viewModel.state.showsOptionsSection {
                optionsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func qualitySection(assessment: PassphraseQualityAssessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Passphrase Strength")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text(assessment.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(qualityColor(for: assessment))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.08))

                    Capsule(style: .continuous)
                        .fill(qualityColor(for: assessment))
                        .frame(width: max(proxy.size.width * assessment.score, 12))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.dialog.showTypingToggleAvailable {
                Toggle("Show typing", isOn: $viewModel.showTypedPassphrase)
                    .toggleStyle(.checkbox)
            }

            if viewModel.dialog.canUseKeychain {
                Toggle("Remember in Keychain", isOn: $viewModel.saveInKeychain)
                    .toggleStyle(.checkbox)
            }
        }
        .font(.system(size: 13))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }

    private var buttonsSection: some View {
        VStack(spacing: 10) {
            Button(action: viewModel.confirm) {
                Text(viewModel.primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryStackedButtonStyle())
            .disabled(!viewModel.isPrimaryActionEnabled)
            .keyboardShortcut(.defaultAction)

            if let tertiaryActionTitle = viewModel.tertiaryActionTitle {
                Button(action: viewModel.decline) {
                    Text(tertiaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryStackedButtonStyle())
            }

            Button(action: viewModel.cancel) {
                Text(viewModel.secondaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryStackedButtonStyle())
            .keyboardShortcut(.cancelAction)
        }
        .padding(.top, 2)
    }

    private func passwordField(placeholder: String, text: Binding<String>, field: Field) -> some View {
        Group {
            if viewModel.showTypedPassphrase {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .focused($focusedField, equals: field)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThickMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 28, y: 18)
    }

    private var iconForegroundStyle: some ShapeStyle {
        if case .systemSymbol = viewModel.dialog.iconSource {
            return AnyShapeStyle(Color.accentColor.opacity(0.92))
        }

        return AnyShapeStyle(Color.primary)
    }

    private func qualityColor(for assessment: PassphraseQualityAssessment) -> Color {
        switch assessment.grade {
        case .strong:
            return Color(nsColor: .systemGreen)
        case .good:
            return Color(nsColor: .systemYellow)
        case .fair:
            return Color(nsColor: .systemOrange)
        case .weak:
            return Color(nsColor: .systemRed)
        }
    }
}

private struct EmptyCardPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color.secondary)

            Text("No active pinentry request")
                .font(.system(size: 18, weight: .semibold))

            Text("The presentation coordinator will attach the next dialog here.")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThickMaterial)
        )
    }
}

struct PrimaryStackedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.vertical, 13)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 0.96))
            )
            .scaleEffect(configuration.isPressed ? 0.995 : 1.0)
    }
}

struct SecondaryStackedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .padding(.vertical, 13)
            .foregroundStyle(Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.46 : 0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

struct DialogCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(title: "Minimal", model: PreviewDialogs.minimalPassphrase)
            preview(title: "Long Description", model: PreviewDialogs.longMessage)
            preview(title: "Error State", model: PreviewDialogs.errorState)
            preview(title: "Repeat Entry", model: PreviewDialogs.repeatEntry)
            preview(title: "Quality Bar", model: PreviewDialogs.qualityEntry)
            preview(title: "Options", model: PreviewDialogs.optionsEntry)
            preview(title: "Confirm", model: PreviewDialogs.confirmOnly)
        }
        .preferredColorScheme(.light)
    }

    private static func preview(title: String, model: DialogModel) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedWhite: 0.96, alpha: 1.0)),
                    Color(nsColor: NSColor(calibratedWhite: 0.88, alpha: 1.0))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            DialogCardView(
                viewModel: DialogViewModel(dialog: model)
            )
            .padding(36)
        }
        .frame(width: 560, height: 540)
        .previewDisplayName(title)
    }
}
