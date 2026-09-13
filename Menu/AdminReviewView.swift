import SwiftUI

/// Only reachable via the dedicated `AdminLoginView` (see ContentView) or,
/// on a session that's already signed in as the admin email, automatically.
/// Manual approval gate for newly created restaurants, matching the "review
/// before it goes live" pattern used by delivery platforms — every new
/// restaurant starts unpublished.
struct AdminReviewView: View {
    @Environment(AppStore.self) private var store
    private var isArabic: Bool { store.language == .arabic }

    private var totalProducts: Int { store.restaurants.reduce(0) { $0 + $1.allItems.count } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                content
            }
        }
        .background(Color.mBackground)
        .ignoresSafeArea(edges: .top)
        .task { await store.loadPendingRestaurants() }
        .refreshable {
            await store.loadPendingRestaurants()
            await store.loadRestaurants()
        }
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 16) {
            HStack {
                Button {
                    Task { await store.signOut() }
                } label: {
                    Text(isArabic ? "خروج" : "Sign Out")
                        .font(.plexArabic(11.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(isArabic ? "الإدارة" : "Admin")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mAdminTextSecondary)
                    Text("menu.")
                        .font(.plexMono(21, weight: .heavy))
                        .foregroundStyle(.white)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            Text(store.currentUserEmail ?? "")
                .font(.plexMono(12))
                .foregroundStyle(Color.mAdminTextSecondary)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 9) {
                MStatTile(value: "\(store.pendingRestaurants.count)", label: isArabic ? "طلب جديد" : "New Requests")
                MStatTile(value: "\(store.restaurants.count)", label: isArabic ? "مطعم منشور" : "Live Stores")
                MStatTile(value: "\(totalProducts)", label: isArabic ? "منتج" : "Items")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 22)
        .background(Color.mAdminBg)
    }

    private var content: some View {
        VStack(alignment: .trailing, spacing: 24) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(isArabic ? "طلبات بانتظار الموافقة" : "Requests Awaiting Approval")
                    .font(.plexArabicHeavy(16))
                    .foregroundStyle(Color.mInk)
                Text(isArabic ? "لا يظهر المطعم للعملاء إلا بعد اعتماده." : "A restaurant stays hidden from customers until it's approved.")
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            if store.pendingRestaurants.isEmpty {
                emptyPendingState
            } else {
                VStack(spacing: 12) {
                    ForEach(store.pendingRestaurants) { restaurant in
                        PendingRestaurantCard(restaurant: restaurant)
                    }
                }
            }

            if !store.restaurants.isEmpty {
                Text(isArabic ? "المطاعم المنشورة" : "Live Stores")
                    .font(.plexArabicHeavy(16))
                    .foregroundStyle(Color.mInk)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(spacing: 8) {
                    ForEach(store.restaurants) { restaurant in
                        LiveRestaurantRow(restaurant: restaurant)
                    }
                }
            }
        }
        .padding(20)
    }

    private var emptyPendingState: some View {
        VStack(spacing: 12) {
            MenyuMascot(variant: .apron, bobDuration: 3.2)
                .frame(width: 76, height: 90)
            Text(isArabic ? "لا توجد طلبات جديدة حاليًا." : "No new requests right now.")
                .font(.plexArabic(13))
                .foregroundStyle(Color.mSage900)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color.mSage100)
        .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
    }
}

private struct PendingRestaurantCard: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack {
                MTag(text: isArabic ? "تحت المراجعة" : "Under Review", style: .tinted(.mAccent100, .mAccent900))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(restaurant.displayName(store.language))
                        .font(.plexArabicHeavy(15.5))
                        .foregroundStyle(Color.mInk)
                    Text("\(restaurant.type.label(store.language)) · \(restaurant.allItems.count) \(isArabic ? "منتج" : "items")")
                        .font(.plexArabic(11.5))
                        .foregroundStyle(Color.mInkTertiary)
                }
                PhotoUploadSlot(imageURL: restaurant.imageURL, size: 66, radius: MTheme.radiusLogo, tint: .mAccent100)
            }

            HStack(spacing: 9) {
                Button(role: .destructive) {
                    Task { await store.rejectRestaurant(restaurant.id) }
                } label: {
                    Text(isArabic ? "رفض" : "Reject")
                }
                .buttonStyle(.mSecondary(fullWidth: false))

                Button {
                    Task { await store.approveRestaurant(restaurant.id) }
                } label: {
                    Text(isArabic ? "اعتماد ونشر" : "Approve & Publish")
                }
                .buttonStyle(.mPrimary(.mSage))
            }
        }
        .padding(14)
        .mCardStyle()
    }
}

private struct LiveRestaurantRow: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.suspendRestaurant(restaurant.id) }
            } label: {
                Text(isArabic ? "إيقاف" : "Suspend")
                    .font(.plexArabic(11, weight: .bold))
                    .foregroundStyle(Color.mInkSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.mChipFill)
                    .clipShape(Capsule())
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(restaurant.displayName(store.language))
                    .font(.plexArabicHeavy(14))
                    .foregroundStyle(Color.mInk)
                Text("\(restaurant.type.label(store.language)) · \(restaurant.allItems.count) \(isArabic ? "منتج" : "items")")
                    .font(.plexArabic(11))
                    .foregroundStyle(Color.mInkTertiary)
            }
            Spacer()
            PhotoUploadSlot(imageURL: restaurant.imageURL, size: 44, radius: MTheme.radiusSmall, tint: .mSage100)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.mSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.mHairline, lineWidth: 1))
    }
}
