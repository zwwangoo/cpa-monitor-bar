extension MonitorViewModel {
    func login(password providedPassword: String) async {
        guard let credentialStore else { return }
        do {
            let password = try resolvePassword(providedPassword, from: credentialStore)
            await authenticate(
                password: password,
                passwordToSave: providedPassword.isEmpty ? nil : providedPassword
            )
        } catch {
            loginError = displayMessage(error)
            isAuthenticated = false
        }
    }

    func loginWithSavedPassword() async {
        guard let credentialStore else { return }
        do {
            guard let password = try credentialStore.loadPassword(), !password.isEmpty else {
                return
            }
            await authenticate(password: password, passwordToSave: nil)
        } catch {
            loginError = displayMessage(error)
            isAuthenticated = false
        }
    }

    func logout() async {
        guard let client else { return }
        let generation = beginConnectionStateChange()
        do { try await client.logout() }
        catch { loginError = displayMessage(error) }
        guard isCurrent(generation) else { return }
        isAuthenticated = false
    }

    private func authenticate(password: String, passwordToSave: String?) async {
        guard let client, let credentialStore else { return }
        let generation = beginConnectionStateChange()
        loginError = nil
        do {
            try await client.login(password: password)
            let session = try await client.session()
            guard isCurrent(generation), session.authenticated else {
                if isCurrent(generation) { loginError = "登录成功响应未建立管理员会话" }
                return
            }
            if let passwordToSave { try credentialStore.savePassword(passwordToSave) }
            isAuthenticated = true
            await refresh()
            startPolling()
        } catch {
            guard isCurrent(generation) else { return }
            loginError = displayMessage(error)
            isAuthenticated = false
        }
    }
}
