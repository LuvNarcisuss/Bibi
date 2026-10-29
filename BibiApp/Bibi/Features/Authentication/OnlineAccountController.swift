import UIKit

/// Account entry uses verified email sessions and explicit, versioned adult consent.
final class OnlineAccountController: StackScreen {
    var onContinue: (() -> Void)?
    private let email = UITextField()
    private let password = UITextField()
    private let adult = UISwitch()
    private let status = UILabel()
    private var working = false
    private var recovering = false

    override func build() {
        super.build()
        title = "Welcome to Bibi"
        content.addArrangedSubview(label("Your anime universe", 28, title: true))
        email.placeholder = "Email"; email.keyboardType = .emailAddress
        email.textContentType = .username; email.autocapitalizationType = .none
        email.autocorrectionType = .no
        password.placeholder = "Password (at least 8 characters)"
        password.isSecureTextEntry = true; password.textContentType = .password
        for field in [email, password] {
            field.borderStyle = .roundedRect; field.font = BibiPalette.font(17)
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            content.addArrangedSubview(field)
        }
        let declaration = label("I am 18 or older and accept the Terms of Service and Privacy Policy.", 15)
        declaration.numberOfLines = 0
        adult.accessibilityLabel = "I am 18 or older and accept the agreements"
        let consent = UIStackView(arrangedSubviews: [declaration, adult]); consent.spacing = 12; consent.alignment = .center
        content.addArrangedSubview(consent)
        for document in AgreementDocument.allCases {
            content.addArrangedSubview(actionButton(document.title, icon: .info) { [weak self] in
                guard let self else { return }; self.push(AgreementController(store: self.store, document: document))
            })
        }
        add("Sign in") { controller in
            guard let services = controller.store.online?.services else { throw BackendError.unavailable }
            try await services.signIn(email: controller.email.text ?? "", password: controller.password.text ?? "",
                adult: controller.adult.isOn, agreement: BibiUserAgreement.version)
            try await controller.enter()
        }
        add("Create account") { controller in
            guard let services = controller.store.online?.services else { throw BackendError.unavailable }
            try await services.signUp(email: controller.email.text ?? "", password: controller.password.text ?? "", adult: controller.adult.isOn)
            controller.status.text = "Check your email to verify your account, then sign in. Open the link on this iPhone."
        }
        add("Resend verification email") { controller in
            try await controller.store.online?.services.resend(email: controller.email.text ?? "")
            controller.status.text = "If verification is needed, check your email."
        }
        add("Forgot password") { controller in
            try await controller.store.online?.services.resetPassword(email: controller.email.text ?? "")
            controller.status.text = "If this email has an account, a reset link will arrive. Open it on this iPhone."
        }
        add("Save new password") { controller in
            guard controller.recovering else { throw BackendError.invalidInput("Open the password reset link from your email first.") }
            try await controller.store.online?.services.updatePassword(controller.password.text ?? "")
            controller.recovering = false; controller.password.text = ""
            controller.status.text = "Password updated. Sign in with your new password."
        }
        add("Finish email verification") { controller in
            guard let services = controller.store.online?.services else { throw BackendError.unavailable }
            try await services.finishVerification(adult: controller.adult.isOn, agreement: BibiUserAgreement.version)
            try await controller.enter()
        }
        add("Resume account deletion") { controller in
            try await controller.store.online?.services.resumeDeletion(email: controller.email.text ?? "", password: controller.password.text ?? "")
            controller.password.text = ""; controller.status.text = "Your online account has been deleted."
        }
        status.numberOfLines = 0; status.font = BibiPalette.font(15); status.textColor = BibiPalette.ink
        status.accessibilityTraits = .updatesFrequently
        content.addArrangedSubview(status)
        status.text = store.loadError
    }

    // Form state must survive store publications during authentication.
    override func refresh() {}
    private func add(_ title: String, operation: @escaping (OnlineAccountController) async throws -> Void) {
        content.addArrangedSubview(actionButton(title, icon: .me) { [weak self] in
            guard let self, !self.working else { return }
            self.working = true; self.status.text = "Please wait…"
            Task { @MainActor in
                defer { self.working = false }
                do { try await operation(self) }
                catch { self.status.text = error.localizedDescription }
            }
        })
    }
    private func enter() async throws {
        try await store.completeOnlineSignIn()
        password.text = ""; onContinue?()
    }
    func handleCallback(_ url: URL) {
        loadViewIfNeeded()
        guard !working else { status.text = "Please finish the current request, then reopen the email link."; return }
        working = true
        Task { @MainActor in
            defer { working = false }
            do {
                guard let services = store.online?.services else { throw BackendError.unavailable }
                try await services.completeCallback(url)
                recovering = services.phase == .recovery
                password.text = ""
                password.textContentType = recovering ? .newPassword : .password
                status.text = recovering ? "Enter a new password, then choose Save new password."
                    : "Email verified. Confirm the age and agreement declaration, then finish verification."
            } catch { status.text = error.localizedDescription }
        }
    }
}
