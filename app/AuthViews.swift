import SwiftUI
import PhotosUI
import UIKit

// MARK: - Landing screen

struct AuthLandingView: View {
    @State private var googleError: String?
    @State private var rotateBrain = false
    @State private var goToSigninFromGoogle = false   // go to Sign in when Google pressed

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // 1st third: title centered
                        ZStack {
                            Text("Memento")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(height: geo.size.height / 3)

                        // 2nd third: rotating brain
                        ZStack {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(rotateBrain ? 360 : 0))
                                .animation(
                                    .linear(duration: 6)
                                        .repeatForever(autoreverses: false),
                                    value: rotateBrain
                                )
                        }
                        .frame(height: geo.size.height / 3)

                        // 3rd third: buttons
                        ZStack {
                            VStack(spacing: 16) {
                                HStack(spacing: 16) {
                                    NavigationLink {
                                        SignupView()
                                    } label: {
                                        AuthPillLabel(title: "Sign up")
                                    }

                                    NavigationLink {
                                        SigninView()
                                    } label: {
                                        AuthPillLabel(title: "Sign in")
                                    }
                                }

                                Button(action: handleGoogleSignInPlaceholder) {
                                    GooglePillLabel()
                                }

                                if let googleError {
                                    Text(googleError)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                        .frame(height: geo.size.height / 3)
                    }

                    // Hidden link to Sign in when Google button tapped
                    NavigationLink(
                        destination: SigninView(),
                        isActive: $goToSigninFromGoogle
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .onAppear {
                    rotateBrain = true
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func handleGoogleSignInPlaceholder() {
        // For now, just send them to normal Sign in
        goToSigninFromGoogle = true
    }
}

// MARK: - Shared pill button styles

struct PillContainer<Content: View>: View {
    let content: () -> Content

    var body: some View {
        content()
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black, lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(radius: 1)
    }
}

struct AuthPillLabel: View {
    let title: String

    var body: some View {
        PillContainer {
            HStack {
                Spacer()
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
            }
        }
    }
}

struct GooglePillLabel: View {
    var body: some View {
        PillContainer {
            HStack(spacing: 8) {
                Image("google_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                Spacer()

                Text("Sign in with Google")
                    .font(.headline)
                    .foregroundColor(.black)

                Spacer()
            }
        }
    }
}

// MARK: - Signup View

struct SignupView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var dob = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(header: Text("Create account")) {
                TextField("Full name", text: $name)
                    .textContentType(.name)

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)

                DatePicker(
                    "Date of birth",
                    selection: $dob,
                    in: ...Date(),
                    displayedComponents: .date
                )
            }

            if let emailError = emailValidationError {
                Text(emailError)
                    .foregroundColor(.red)
            }

            if let dobError = dobValidationError {
                Text(dobError)
                    .foregroundColor(.red)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isFormValid || isSubmitting)
            }
        }
        .navigationTitle("Sign up")
    }

    private var emailValidationError: String? {
        guard !email.isEmpty else { return nil }
        return isValidEmail(email) ? nil : "Please enter a valid email address."
    }

    private var dobValidationError: String? {
        let cal = Calendar.current
        let now = Date()
        guard dob <= now else { return "DOB cannot be in the future." }

        if let thirteenYearsAgo = cal.date(byAdding: .year, value: -13, to: now),
           dob > thirteenYearsAgo {
            return "You must be at least 13 years old."
        }
        return nil
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        isValidEmail(email) &&
        dobValidationError == nil
    }

    private func submit() async {
        guard isFormValid else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            try await AuthAPI.shared.signup(
                name: name,
                email: email,
                password: password,
                dob: dob
            )
            dismiss()
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

// MARK: - Sign in View

struct SigninView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("currentEmail") private var currentEmail = ""

    var body: some View {
        Form {
            Section(header: Text("Welcome back")) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(email.isEmpty || password.isEmpty || isSubmitting)
            }
        }
        .navigationTitle("Sign in")
    }

    private func submit() async {
        guard !email.isEmpty, !password.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            _ = try await AuthAPI.shared.signin(email: email, password: password)
            currentEmail = email
            isLoggedIn = true
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

// MARK: - Home sections enum

enum HomeSection {
    case home
    case profile
    case streams
    case addFamily
    case addPets
    case chatHistory
    case settings
}

// MARK: - Home View

struct HomeView: View {
    @State private var isMenuOpen = false
    @State private var currentSection: HomeSection = .home
    @AppStorage("isLoggedIn") private var isLoggedIn = false

    private let menuItems: [HomeSection] = [
        .profile,
        .streams,
        .addFamily,
        .addPets,
        .chatHistory,
        .settings
    ]

    private let versionText = "Version 1.0.0 © Memento"
    private let navBarHeight: CGFloat = 56

    private var isOnHome: Bool { currentSection == .home }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // Main app stack: top navbar, main content, bottom bar
                VStack(spacing: 0) {
                    topNavBar

                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    bottomBar(bottomSafeArea: geo.safeAreaInsets.bottom)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color(.systemBackground))
                .ignoresSafeArea(edges: .bottom)

                // Right-side sliding menu overlay
                if isMenuOpen {
                    HStack(spacing: 0) {
                        // Left 30%: empty area to close menu
                        Color.clear
                            .frame(width: geo.size.width * 0.3)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    isMenuOpen = false
                                }
                            }

                        // Right 70%: menu, aligned with navbar using top safe area
                        sideMenu(
                            width: geo.size.width * 0.7,
                            topSafeArea: geo.safeAreaInsets.top
                        )
                    }
                    .ignoresSafeArea()
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut, value: isMenuOpen)
        }
    }

    // MARK: - Top nav bar

    private var topNavBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)

                Text("Memento")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut) {
                    isMenuOpen.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .frame(height: navBarHeight)
        .padding(.horizontal, 16)
        .background(Color.red)
    }

    // MARK: - Main content for each section

    @ViewBuilder
    private var mainContent: some View {
        switch currentSection {
        case .home:
            HomeChatView()

        case .profile:
            ProfileView()

        case .streams:
            StreamsView()
            
        case .addFamily:
            AddFamilyView()

        case .addPets:
            AddPetsView()

        case .chatHistory:
            ChatHistoryView()

        case .settings:
            SettingsView()
        }
    }

    // MARK: - Bottom bar: Streams – Home/Mic – History

    private func bottomBar(bottomSafeArea: CGFloat) -> some View {
        let baseHeight: CGFloat = 70

        return ZStack {
            Color.white
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: -2)

            HStack {
                // Streams button
                Button {
                    withAnimation(.easeInOut) {
                        currentSection = .streams
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "rectangle.stack.badge.play")
                            .font(.system(size: 20, weight: .regular))
                        Text("Streams")
                            .font(.footnote)
                    }
                    .foregroundColor(currentSection == .streams ? .blue : .gray)
                }

                Spacer()

                // Center floating button: Home (when not on home) or Mic (when on home)
                Button {
                    if !isOnHome {
                        withAnimation(.easeInOut) {
                            currentSection = .home
                        }
                    } else {
                        // On home: acts like a mic; no backend logic yet
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.red)  // red background as requested
                            Image(systemName: isOnHome ? "mic.fill" : "house.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                        }
                        .frame(width: 56, height: 56)

                        Text(isOnHome ? "Mic" : "Home")
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                // History button (opens Chat History)
                Button {
                    withAnimation(.easeInOut) {
                        currentSection = .chatHistory
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .regular))
                        Text("History")
                            .font(.footnote)
                    }
                    .foregroundColor(currentSection == .chatHistory ? .blue : .gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, bottomSafeArea > 0 ? bottomSafeArea : 8)
        }
        .frame(height: baseHeight + bottomSafeArea)
    }

    // MARK: - Side menu on the right (aligned with navbar)

    private func sideMenu(width: CGFloat, topSafeArea: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.blue
                .frame(width: width)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // Push everything down so X aligns with nav bar row
                Color.clear
                    .frame(height: topSafeArea)

                // Row aligned with navbar
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) {
                            isMenuOpen = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(4)
                    }
                }
                .frame(height: navBarHeight)
                .padding(.trailing, 16)

                // Divider to mark bottom of nav row
                Divider()
                    .background(Color.white.opacity(0.7))

                // Menu items start clearly below nav row
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(menuItems, id: \.self) { section in
                        Button {
                            withAnimation(.easeInOut) {
                                currentSection = section
                                isMenuOpen = false
                            }
                        } label: {
                            Text(title(for: section))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Sign Out (logic unchanged)
                    Button {
                        withAnimation(.easeInOut) {
                            isMenuOpen = false
                        }
                        isLoggedIn = false
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 32)                 // push Profile down below navbar
                .padding(.leading, 24)

                Spacer()

                // Footer: version + copyright
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .background(Color.white.opacity(0.7))

                    Text(versionText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 24)
                .padding(.leading, 24)
            }
        }
    }

    private func title(for section: HomeSection) -> String {
        switch section {
        case .profile:      return "Profile"
        case .streams:      return "Streams"
        case .addFamily:    return "Add Family"
        case .addPets:      return "Add Pets"
        case .chatHistory:  return "Chat History"
        case .settings:     return "Settings"
        case .home:         return "Home"
        }
    }
}

// MARK: - Home chat-style view

struct HomeChatView: View {
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to Memento!")
                        .font(.title2.bold())

                    Text("Ask about your home, your cameras, or your day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer().frame(height: 12)

                    Text("Examples:")
                        .font(.subheadline.bold())
                    Text("• What happened at the front door this morning?")
                    Text("• Show me all motion events in the living room.")
                    Text("• Summarize today’s activity in the kitchen.")
                    Text("• Help me find my spectacles.")
                }
                .padding()
            }

            // Pretty input bar
            VStack(spacing: 0) {
                Divider()

                HStack(spacing: 12) {

                    // Rounded text area
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)

                        ZStack(alignment: .leading) {
                            if inputText.isEmpty {
                                Text("Ask Memento anything…")
                                    .foregroundColor(.secondary)
                            }

                            TextField("", text: $inputText)
                                .textFieldStyle(.plain)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    // Circular send button
                    Button {
                        // ignore submit logic for now
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .shadow(radius: 1)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .background(Color.black.opacity(0.2))
            }

        }
    }
}



// MARK: - Profile View

struct ProfileView: View {
    @AppStorage("currentEmail") private var currentEmail = ""

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var dob: Date = Date()
    @State private var originalEmail: String = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack {
                        // Initial avatar
                        Circle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(initialLetter)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        Text("Account Profile")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                }

                Section(header: Text("Account Info")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    DatePicker(
                        "Date of Birth",
                        selection: $dob,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .foregroundColor(.green)
                }

                Section {
                    Button {
                        Task { await saveProfileDemoOnly() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Edit")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent) // blue filled
                    .tint(.blue)
                    .disabled(isSaving || name.isEmpty || email.isEmpty)
                }
            }
            .navigationTitle("Profile")
        }
        .onAppear {
            Task { await loadProfile() }
        }
    }

    private var initialLetter: String {
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(name.trimmingCharacters(in: .whitespaces).first ?? "M")
        } else if !email.isEmpty {
            return String(email.first ?? "M")
        } else {
            return "M"
        }
    }

    private func loadProfile() async {
        guard !currentEmail.isEmpty else {
            isLoading = false
            errorMessage = "No email for current user."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        do {
            let profile = try await AuthAPI.shared.fetchProfile(email: currentEmail)
            name = profile.name
            email = profile.email
            originalEmail = profile.email

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withFullDate]
            if let d = iso.date(from: profile.dob) {
                dob = d
            }

        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // Demo-only: no backend call, just a fake "saved" message
    private func saveProfileDemoOnly() async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil

        try? await Task.sleep(nanoseconds: 400_000_000)
        infoMessage = "Changes not saved (demo only)."
        isSaving = false
    }
}

// MARK: - Streams View

struct StreamsView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No camera streams available")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Chat History View

struct ChatHistoryView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No camera streams available")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var notificationsOn = false
    @State private var saveCameraSummaries = true
    @State private var darkModeOn = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Enable notifications", isOn: $notificationsOn)
                    Toggle("Daily activity summary", isOn: $saveCameraSummaries)
                }

                Section(header: Text("Appearance")) {
                    Toggle("Dark mode", isOn: $darkModeOn)
                }

                Section(header: Text("Account")) {
                    Button {
                        // frontend-only delete account
                    } label: {
                        Text("Delete Account")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)  // red background, white text
                }

                Section(header: Text("Other")) {
                    Toggle("Send anonymous usage data", isOn: .constant(true))
                        .disabled(true)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Add Family View

struct AddFamilyView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var name: String = ""
    @State private var height: String = ""
    @State private var age: String = ""
    @State private var relation: String = ""

    @State private var infoMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Family Member Photo")) {
                    PhotosPicker(selection: $selectedItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        HStack {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .foregroundColor(.gray)
                                    )
                            }

                            Text(selectedImage == nil ? "Select photo" : "Change photo")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task { await loadImage(from: newItem) }
                    }
                }

                Section(header: Text("Details")) {
                    TextField("Name", text: $name)
                    TextField("Height (e.g. 5'8\" or 172 cm)", text: $height)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    TextField("Relation (e.g. Father, Sister)", text: $relation)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .foregroundColor(.green)
                }

                Section {
                    Button {
                        submitFamilyMember()
                    } label: {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(name.isEmpty || relation.isEmpty)
                }
            }
            .navigationTitle("Add Family")
        }
    }

    private func submitFamilyMember() {
        // FRONTEND ONLY – no backend call yet
        guard !name.isEmpty, !relation.isEmpty else {
            errorMessage = "Name and relation are required."
            infoMessage = nil
            return
        }

        infoMessage = "Family member added (demo only)."
        errorMessage = nil

        name = ""
        height = ""
        age = ""
        relation = ""
        selectedImage = nil
        selectedItem = nil
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        } catch {
            errorMessage = "Could not load image."
        }
    }
}

// MARK: - Add Pets View

struct AddPetsView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var petType: String = ""
    @State private var petName: String = ""
    @State private var color: String = ""
    @State private var extraFeatures: String = ""

    @State private var infoMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pet Photo")) {
                    PhotosPicker(selection: $selectedItem,
                                 matching: .images,
                                 photoLibrary: .shared()) {
                        HStack {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .foregroundColor(.gray)
                                    )
                            }

                            Text(selectedImage == nil ? "Select photo" : "Change photo")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItem) { newItem in
                        Task { await loadImage(from: newItem) }
                    }
                }

                Section(header: Text("Details")) {
                    TextField("Pet type (e.g. Dog, Cat)", text: $petType)
                    TextField("Name (optional)", text: $petName)
                    TextField("Color", text: $color)
                    TextField("Additional features", text: $extraFeatures, axis: .vertical)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if let infoMessage {
                    Text(infoMessage)
                        .foregroundColor(.green)
                }

                Section {
                    Button {
                        submitPet()
                    } label: {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(petType.isEmpty)
                }
            }
            .navigationTitle("Add Pets")
        }
    }

    private func submitPet() {
        // FRONTEND ONLY – no backend call yet
        guard !petType.isEmpty else {
            errorMessage = "Pet type is required."
            infoMessage = nil
            return
        }

        infoMessage = "Pet added (demo only)."
        errorMessage = nil

        petType = ""
        petName = ""
        color = ""
        extraFeatures = ""
        selectedImage = nil
        selectedItem = nil
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                selectedImage = uiImage
            }
        } catch {
            errorMessage = "Could not load image."
        }
    }
}

// MARK: - Networking layer

struct AuthTokenResponse: Decodable {
    let token: String
}

struct UserProfile: Codable {
    let name: String
    let email: String
    let dob: String   // ISO 8601 full-date string
}

enum AuthError: Error, LocalizedError {
    case server(String)
    case emailAlreadyInUse
    case invalidResponse
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .server(let msg):
            return msg
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in instead."
        case .invalidResponse:
            return "Invalid response from server."
        case .profileNotFound:
            return "Profile not found on server."
        }
    }
}

final class AuthAPI {
    static let shared = AuthAPI()

    // Replace with your real backend URL
    private let baseURL = URL(string: "https://mementoapp-apdma2cscdhhrcg.northcentralus-01.azurewebsites.net")!

    private init() {}

    // ----- Signup / Signin -----

    func signup(name: String, email: String, password: String, dob: Date) async throws {
        struct Payload: Encodable {
            let name: String
            let email: String
            let password: String
            let dob: String
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        let payload = Payload(
            name: name,
            email: email,
            password: password,
            dob: iso.string(from: dob)
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("/signup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""

            if body.localizedCaseInsensitiveContains("user already exists") ||
               body.localizedCaseInsensitiveContains("email already exists") {
                throw AuthError.emailAlreadyInUse
            }

            throw AuthError.server(body.isEmpty ? "Signup failed." : body)
        }
    }

    func signin(email: String, password: String) async throws -> String {
        struct Payload: Encodable {
            let email: String
            let password: String
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/signin"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Payload(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Sign in failed."
            throw AuthError.server(body)
        }

        let decoded = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        return decoded.token
    }

    // ----- Profile APIs -----

    func fetchProfile(email: String) async throws -> UserProfile {
        var components = URLComponents(url: baseURL.appendingPathComponent("/profile"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "email", value: email)]
        guard let url = components.url else {
            throw AuthError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw AuthError.profileNotFound
            }
            let body = String(data: data, encoding: .utf8) ?? "Failed to load profile."
            throw AuthError.server(body)
        }

        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    // Available for future use when you want real edit logic
    func updateProfile(originalEmail: String, profile: UserProfile) async throws {
        struct Payload: Encodable {
            let original_email: String
            let name: String
            let email: String
            let dob: String
        }

        let payload = Payload(
            original_email: originalEmail,
            name: profile.name,
            email: profile.email,
            dob: profile.dob
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("/profile"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Failed to update profile."
            throw AuthError.server(body)
        }
    }
}

// MARK: - Simple validators

func isValidEmail(_ email: String) -> Bool {
    let pattern = #"^\S+@\S+\.\S+$"#
    return email.range(of: pattern, options: .regularExpression) != nil
}

