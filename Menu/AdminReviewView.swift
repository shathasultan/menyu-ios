import SwiftUI

/// Only reachable when AppStore.isAdmin is true (see ContentView). Manual approval
/// gate for newly created restaurants, matching the "review before it goes live"
/// pattern used by delivery platforms — every new restaurant starts unpublished.
struct AdminReviewView: View {
    @Environment(AppStore.self) private var store
    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            Group {
                if store.pendingRestaurants.isEmpty {
                    ContentUnavailableView(
                        isArabic ? "لا يوجد شيء بانتظار المراجعة" : "Nothing to review",
                        systemImage: "checkmark.seal",
                        description: Text(isArabic
                            ? "كل المطاعم الجديدة معتمدة حاليًا"
                            : "All new restaurants are approved")
                    )
                } else {
                    List(store.pendingRestaurants) { restaurant in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(restaurant.displayName(store.language))
                                    .font(.plexArabic(15, weight: .bold))
                                    .foregroundStyle(Color.mInk)
                                Spacer()
                                Text(restaurant.type.label(store.language))
                                    .font(.plexArabic(11, weight: .semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.mAccentSoft)
                                    .foregroundStyle(Color.mAccentStrong)
                                    .clipShape(Capsule())
                            }
                            Text("\(restaurant.categories.count) \(isArabic ? "تصنيف" : "categories") · \(restaurant.allItems.count) \(isArabic ? "منتج" : "items")")
                                .font(.plexArabic(12))
                                .foregroundStyle(Color.mInkSoft)

                            Button {
                                Task { await store.approveRestaurant(restaurant.id) }
                            } label: {
                                Text(isArabic ? "اعتماد ونشر" : "Approve & Publish")
                                    .font(.plexArabic(13.5, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(Color.mAccent)
                                    .foregroundStyle(Color.mAccentInk)
                                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.mSurface)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
                }
            }
            .navigationTitle(isArabic ? "مراجعة المطاعم" : "Review")
            .task { await store.loadPendingRestaurants() }
            .refreshable { await store.loadPendingRestaurants() }
        }
    }
}
