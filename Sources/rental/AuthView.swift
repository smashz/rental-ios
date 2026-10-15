import SwiftUI

/// Login / registration gate. The same account authenticates against the web
/// dashboard's `/api/auth/*` endpoints, so one sign-in works in both places.
struct AuthView: View {
    @EnvironmentObject var store: DataStore
    @State private var isRegister = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    logo
                    card
                    demoHint
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
    }

    private var logo: some View {
        VStack(spacing: 10) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.accent)
            Text("Rental").font(.system(size: 30, weight: .heavy)).foregroundColor(Theme.ink)
            Text("Find your drive").font(.subheadline).foregroundColor(Theme.subtle)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Picker("", selection: $isRegister) {
                Text("Log in").tag(false)
                Text("Register").tag(true)
            }
            .pickerStyle(.segmented)

            if isRegister {
                field("Name", text: $name, icon: "person")
            }
            field("Email", text: $email, icon: "envelope", keyboard: .emailAddress)
            field("Password", text: $password, icon: "lock", secure: true)

            if let err = store.authError {
                Text(err).font(.footnote).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(title: busy ? "Please wait…" : (isRegister ? "Create account" : "Log in"),
                          enabled: !busy && canSubmit) {
                Task { await submit() }
            }
        }
        .padding(20)
        .card()
    }

    private var demoHint: some View {
        VStack(spacing: 4) {
            Text("Demo account").font(.caption.weight(.semibold)).foregroundColor(Theme.subtle)
            Text("demo@rental.app · demo1234").font(.caption).foregroundColor(Theme.subtle)
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && (!isRegister || !name.isEmpty)
    }

    private func submit() async {
        busy = true
        defer { busy = false }
        if isRegister {
            _ = await store.register(name: name, email: email, password: password)
        } else {
            _ = await store.login(email: email, password: password)
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, icon: String,
                       secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.subtle).frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .foregroundColor(Theme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }
}
