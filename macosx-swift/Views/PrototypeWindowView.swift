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
        Group {
            if let viewModel = coordinator.activeViewModel {
                DialogCardView(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 25)
        .padding(.bottom, 17)
        .frame(minWidth: 248, idealWidth: 288, maxWidth: 320, alignment: .topLeading)
        .background(Color.clear)
    }
}

struct DialogCardView: View {
    @ObservedObject var viewModel: DialogViewModel
    @FocusState private var focusedField: Field?
    private let actionButtonHeight: CGFloat = 18

    private enum Field: Hashable {
        case passphrase
        case repeatedPassphrase
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                header

                if viewModel.state.showsErrorSection {
                    errorSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if viewModel.dialog.mode == .passphrase {
                    passphraseSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 5)

            buttonsSection
        }
        .frame(minWidth: 220, idealWidth: 270, maxWidth: 320, alignment: .leading)
        .animation(.easeInOut(duration: 0.18), value: viewModel.state.isExpanded)
        .onAppear {
            focusPrimaryPassphraseField()
        }
        .onChange(of: viewModel.showTypedPassphrase) { _ in
            focusPrimaryPassphraseField()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            viewModel.resolveIcon()
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .foregroundStyle(iconForegroundStyle)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.dialog.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.dialog.message)
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                if let keyboardPrompt = viewModel.keyboardPrompt {
                    Text(keyboardPrompt)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    private var errorSection: some View {
        Label {
            Text(viewModel.dialog.errorText ?? "")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.callout)
        .foregroundStyle(Color(nsColor: .systemRed))
    }

    private var passphraseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledPasswordField(
                title: viewModel.promptText,
                text: $viewModel.passphrase,
                field: .passphrase
            )

            if viewModel.state.showsRepeatField {
                labeledPasswordField(
                    title: viewModel.confirmPromptText,
                    text: $viewModel.repeatedPassphrase,
                    field: .repeatedPassphrase
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let mismatchHint = viewModel.mismatchHint {
                Text(mismatchHint)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(nsColor: .systemRed))
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.qualityTitle)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Text(assessment.label)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(qualityColor(for: assessment))
            }

            ProgressView(value: assessment.score)
                .tint(qualityColor(for: assessment))
                .controlSize(.small)
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.dialog.showTypingToggleAvailable {
                Toggle(L10n.showTyping, isOn: $viewModel.showTypedPassphrase)
                    .toggleStyle(.checkbox)
            }

            if viewModel.dialog.canUseKeychain {
                Toggle(L10n.saveInKeychain, isOn: $viewModel.saveInKeychain)
                    .toggleStyle(.checkbox)
            }
        }
        .font(.callout)
    }

    private var buttonsSection: some View {
        VStack(spacing: 10) {
            Button(action: viewModel.confirm) {
                Text(viewModel.primaryActionTitle)
                    .frame(maxWidth: .infinity, minHeight: actionButtonHeight)
            }
            .modifier(PrimaryActionButtonModifier())
            .controlSize(.large)
            .disabled(!viewModel.isPrimaryActionEnabled)
            .keyboardShortcut(.defaultAction)

            if let tertiaryActionTitle = viewModel.tertiaryActionTitle {
                Button(action: viewModel.decline) {
                    Text(tertiaryActionTitle)
                        .frame(maxWidth: .infinity, minHeight: actionButtonHeight)
                }
                .modifier(SecondaryActionButtonModifier())
                .controlSize(.large)
            }

            Button(action: viewModel.cancel) {
                Text(viewModel.secondaryActionTitle)
                    .frame(maxWidth: .infinity, minHeight: actionButtonHeight)
            }
                .modifier(SecondaryActionButtonModifier())
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.top, 6)
    }

    private func labeledPasswordField(title: String, text: Binding<String>, field: Field) -> some View {
        Group {
            if viewModel.showTypedPassphrase {
                TextField(title, text: text)
            } else {
                SecureField(title, text: text)
            }
        }
        .textFieldStyle(.roundedBorder)
        .controlSize(.regular)
        .focused($focusedField, equals: field)
    }

    private func focusPrimaryPassphraseField() {
        guard viewModel.dialog.mode == .passphrase else {
            focusedField = nil
            return
        }

        focusedField = nil

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            focusedField = .passphrase
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            focusedField = .passphrase
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            focusedField = .passphrase
        }
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

private struct PrimaryActionButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.borderedProminent)
        }
    }
}

private struct SecondaryActionButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content
                .buttonStyle(.bordered)
        }
    }
}

struct DialogCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(title: L10n.tr("preview.name.minimal", fallback: "Minimal"), model: PreviewDialogs.minimalPassphrase)
            preview(title: L10n.tr("preview.name.long", fallback: "Long Description"), model: PreviewDialogs.longMessage)
            preview(title: L10n.tr("preview.name.error", fallback: "Error State"), model: PreviewDialogs.errorState)
            preview(title: L10n.tr("preview.name.repeat", fallback: "Repeat Entry"), model: PreviewDialogs.repeatEntry)
            preview(title: L10n.tr("preview.name.quality", fallback: "Quality Bar"), model: PreviewDialogs.qualityEntry)
            preview(title: L10n.tr("preview.name.options", fallback: "Options"), model: PreviewDialogs.optionsEntry)
            preview(title: L10n.tr("preview.name.confirm", fallback: "Confirm"), model: PreviewDialogs.confirmOnly)
        }
        .preferredColorScheme(.light)
    }

    private static func preview(title: String, model: DialogModel) -> some View {
        PrototypeWindowView(
            coordinator: WindowPresentationCoordinator(previewDialog: model)
        )
        .frame(width: 360, height: 430)
        .previewDisplayName(title)
    }
}
