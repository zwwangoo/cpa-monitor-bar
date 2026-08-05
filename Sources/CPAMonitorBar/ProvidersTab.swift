import SwiftUI
import CPAModels

struct ProvidersTab: View {
    let providers: SectionState<UsageIdentitiesPageResponse>
    let usageStates: [String: ProviderUsageState]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let identities = providers.value?.identities, !identities.isEmpty {
                ForEach(identities) { identity in
                    providerRow(identity)
                    if identity.id != identities.last?.id { Divider() }
                }
            } else if !providers.isLoading && providers.errorMessage == nil {
                Text("暂无供应商").foregroundStyle(.tertiary)
            }
            SectionFeedback(state: providers)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("monitor.tab.providers")
    }

    private func providerRow(_ identity: UsageIdentity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preferredText(identity.displayName, identity.provider, identity.name))
                .font(.caption.weight(.semibold))
            if let usageState = usageStates[identity.id] {
                ProviderUsageSummaryView(state: usageState)
                Divider().opacity(0.55)
            }
            CredentialHealthTrend(health: identity.credentialHealth)
        }
    }
}
