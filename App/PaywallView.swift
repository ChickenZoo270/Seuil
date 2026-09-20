import SwiftUI
import IntentionCore
import StoreKit

/// Full-screen subscription sheet. Drives `ProStore` for plans, purchase and restore.
struct PaywallView: View {
    @ObservedObject var store: ProStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlanID: String?
    @State private var showOtherPlans = false

    private struct TimelineStep {
        let symbol: String
        let title: String
        let detail: String
        let filled: Bool
    }

    private let steps: [TimelineStep] = [
        TimelineStep(symbol: "lock.open.fill", title: "Aujourd’hui", detail: "Seuil Pro activé. 0 € aujourd’hui.", filled: true),
        TimelineStep(symbol: "bell.fill", title: "2 jours avant la fin", detail: "On te prévient avant la facturation.", filled: true),
        TimelineStep(symbol: "bolt.fill", title: "Dans 7 jours", detail: "Annule quand tu veux. Aucune surprise.", filled: false),
    ]

    private var plans: [ProPlan] { store.plans }
    private var visiblePlans: [ProPlan] { showOtherPlans ? plans : Array(plans.prefix(2)) }
    private var selectedPlan: ProPlan? { plans.first { $0.id == selectedPlanID } ?? plans.first }
    private var productsUnavailable: Bool { store.products.isEmpty }

    /// What the CTA's small print says: no charge today when there is a free
    /// trial (badge present), otherwise the price charged right away.
    private var chargeSummary: String {
        guard let plan = selectedPlan else { return "Aucun paiement aujourd’hui" }
        return plan.badge != nil ? "Puis \(plan.price) après ton essai gratuit" : "Facturé \(plan.price) aujourd’hui"
    }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(spacing: 28) {
                    header
                    title
                    timeline
                    plansSection
                    // The "products not signed yet" card only makes sense once loading
                    // finished and truly came back empty — during loading it would
                    // flash beneath the skeleton for no reason.
                    if productsUnavailable && !store.isLoading { unavailableCard }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 210)
            }
            .scrollIndicators(.hidden)
            // While StoreKit is still fetching products, redact the whole layout into
            // a skeleton instead of showing empty/placeholder pricing.
            .redacted(reason: store.isLoading ? .placeholder : [])
            .allowsHitTesting(!store.isLoading)
            VStack {
                Spacer()
                footer
                    .redacted(reason: store.isLoading ? .placeholder : [])
            }
        }
        .onAppear { if selectedPlanID == nil { selectedPlanID = plans.first(where: { $0.badge != nil })?.id ?? plans.first?.id } }
        .onChange(of: plans) { _, newPlans in
            if selectedPlanID == nil || !newPlans.contains(where: { $0.id == selectedPlanID }) {
                selectedPlanID = newPlans.first(where: { $0.badge != nil })?.id ?? newPlans.first?.id
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            CircleIconButton(symbol: "xmark", size: 40) { dismiss() }
                .accessibilityIdentifier("paywall.close")
                .accessibilityLabel("Fermer")
        }
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text("Ton parcours commence.")
            Text("Choisis ton essai.")
        }
        .font(.system(size: 30, weight: .bold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(step.filled ? AnyShapeStyle(SeuilTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.06)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(step.filled ? 0 : 0.18), lineWidth: 1.5))
                                .frame(width: 48, height: 48)
                            Image(systemName: step.symbol)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(step.filled ? Color.black : Color.white)
                        }
                        if index < steps.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 2, height: 40)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title).font(.headline)
                        Text(step.detail).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach(visiblePlans) { plan in
                planCard(plan)
            }
            if plans.count > 2 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showOtherPlans.toggle() }
                } label: {
                    Text(showOtherPlans ? "Moins de plans" : "Autres plans")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SeuilTheme.secondaryInk)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planCard(_ plan: ProPlan) -> some View {
        let isSelected = plan.id == selectedPlanID
        return Button {
            selectedPlanID = plan.id
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(plan.title) · \(plan.price)")
                            .font(.title2.weight(.semibold))
                            .minimumScaleFactor(0.8)
                        Text(plan.detail)
                            .font(.subheadline)
                            .foregroundStyle(SeuilTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if !plan.perDay.isEmpty {
                        Text(plan.perDay)
                            .font(.subheadline)
                            .foregroundStyle(SeuilTheme.secondaryInk)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(isSelected ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(isSelected ? AnyShapeStyle(SeuilTheme.accentGradient) : AnyShapeStyle(Color.white.opacity(0.09)),
                                      lineWidth: isSelected ? 2 : 1)
                )

                if let badge = plan.badge {
                    Text(badge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(SeuilTheme.accentGradient, in: Capsule())
                        .offset(x: -10, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall.plan.\(plan.id)")
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Les abonnements ne sont pas encore disponibles")
                .font(.headline)
            Text("Le contrat vendeur d’apps payantes est en cours de validation par Apple. Les offres apparaîtront ici dès qu’il sera signé.")
                .font(.subheadline)
                .foregroundStyle(SeuilTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            RowDivider().padding(.horizontal, -20)
            SettingsToggleRow(icon: "hammer.fill", title: "Débloquer Pro pour tester", isOn: Binding(
                get: { store.isTester },
                set: { store.isTester = $0 }
            ))
            .padding(.horizontal, -20)
            .accessibilityIdentifier("paywall.testerToggle")
        }
        .glassCard(cornerRadius: 24, padding: 20)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text("Annule quand tu veux.")
                .font(.footnote)
                .foregroundStyle(SeuilTheme.secondaryInk)

            Button {
                guard let plan = selectedPlan, let product = store.product(for: plan) else { return }
                Task { await store.purchase(product) }
            } label: {
                VStack(spacing: 2) {
                    Text("Démarrer mon essai gratuit")
                    Text(chargeSummary)
                        .font(.footnote)
                        .opacity(0.7)
                }
            }
            .buttonStyle(PillButtonStyle(variant: .bright))
            .disabled(store.isLoading || productsUnavailable || selectedPlan == nil)
            .accessibilityIdentifier("paywall.cta")

            HStack(spacing: 22) {
                Link("Conditions", destination: URL(string: "https://chickenzoo.com/seuil/terms") ?? URL(fileURLWithPath: "/"))
                Link("Confidentialité", destination: URL(string: "https://chickenzoo.com/seuil/privacy") ?? URL(fileURLWithPath: "/"))
                Button("Restaurer") { Task { await store.restore() } }
            }
            .font(.footnote)
            .foregroundStyle(SeuilTheme.secondaryInk)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.85), .black], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}

// ProBadge lives in SeuilKit.swift and is reused here; redefining it locally
// used to collide with that declaration and would fail to build.

/// List of every Pro feature, used on the paywall or in settings to explain the upgrade.
struct ProFeatureList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(ProFeature.allCases.enumerated()), id: \.element) { index, feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.symbol)
                        .font(.title3)
                        .foregroundStyle(SeuilTheme.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title).font(.body.weight(.medium))
                        Text(feature.summary).font(.subheadline).foregroundStyle(SeuilTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
                if index < ProFeature.allCases.count - 1 { RowDivider() }
            }
        }
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
    }
}
