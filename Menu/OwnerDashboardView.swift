import SwiftUI
import PhotosUI

/// The merchant/owner shell — sage header + pending banner + a 3-tab bottom
/// bar (المنيو / مطعمي / حسابي), matching the design handoff's owner
/// screens 7–10. Manages exactly the restaurant currently selected
/// (`store.selectedRestaurantID`); ContentView shows this whole shell
/// instead of the customer tab bar the moment `myRestaurants` is non-empty.
struct OwnerDashboardShell: View {
    @Environment(AppStore.self) private var store
    @State private var ownerTab: OwnerTab = .menu

    private var isArabic: Bool { store.language == .arabic }

    var selectedRestaurant: Restaurant? {
        store.myRestaurants.first(where: { $0.id == store.selectedRestaurantID })
    }

    var body: some View {
        Group {
            if let restaurant = selectedRestaurant {
                VStack(spacing: 0) {
                    header(restaurant)
                    statusBanner(restaurant)

                    TabView(selection: $ownerTab) {
                        MenuTab(restaurant: restaurant)
                            .tabItem { Label(isArabic ? "المنيو" : "Menu", systemImage: "list.bullet.rectangle") }
                            .tag(OwnerTab.menu)

                        VenueTab(restaurant: restaurant)
                            .tabItem { Label(isArabic ? "مطعمي" : "My Store", systemImage: "storefront") }
                            .tag(OwnerTab.venue)

                        AccountTab()
                            .tabItem { Label(isArabic ? "حسابي" : "Account", systemImage: "person.crop.circle") }
                            .tag(OwnerTab.account)
                    }
                    .tint(Color.mSage700)
                }
            } else {
                VStack { Spacer(); ProgressView(); Spacer() }
                    .background(Color.mBackground)
            }
        }
        .onAppear {
            if store.selectedRestaurantID == nil {
                store.selectedRestaurantID = store.myRestaurants.first?.id
            }
        }
        .onChange(of: store.myRestaurants.count) { _, _ in
            if store.selectedRestaurantID == nil || selectedRestaurant == nil {
                store.selectedRestaurantID = store.myRestaurants.first?.id
            }
        }
    }

    private func header(_ restaurant: Restaurant) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack {
                Button {
                    Task { await store.signOut() }
                } label: {
                    Text(isArabic ? "خروج" : "Sign Out")
                        .font(.plexArabic(11.5, weight: .bold))
                        .foregroundStyle(Color.mSage900)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.mSurface)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(restaurant.displayName(store.language))
                    .font(.plexArabicHeavy(17))
                    .foregroundStyle(Color.mSage900)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 20)
        .background(Color.mSage100)
    }

    /// A live store says nothing; an unpublished one says *why*. Before
    /// migration 0006's `status` reached the app there was only `isPublished`,
    /// so a declined application and one still in the queue looked identical —
    /// a rejected vendor was told, indefinitely, that they were "under review".
    @ViewBuilder
    private func statusBanner(_ restaurant: Restaurant) -> some View {
        if !restaurant.isPublished {
            let rejected = restaurant.status == .rejected
            HStack(spacing: 12) {
                Text(rejected
                     ? (isArabic
                        ? "لم يُعتمد طلبك. راجع بيانات مطعمك وقائمته، ثم تواصل مع الإدارة لإعادة النظر فيه."
                        : "Your application wasn't approved. Review your store details and menu, then contact admin to have it reconsidered.")
                     : (isArabic
                        ? "طلبك قيد مراجعة الإدارة. يمكنك تجهيز قائمتك الآن، وتُنشر للعملاء فور الاعتماد."
                        : "Your request is under admin review. You can prepare your menu now — it publishes to customers the moment it's approved."))
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInk.opacity(0.65))
                    .multilineTextAlignment(.trailing)

                ZStack {
                    Circle().fill(rejected ? Color.mAccent200 : Color.mAccent100).frame(width: 30, height: 30)
                    Image(systemName: rejected ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.mAccent800)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(Color.mSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: MTheme.shadowCard, radius: 10, x: 0, y: 2)
            .padding(.horizontal, 20)
            .padding(.top, -8)
            .padding(.bottom, 8)
            .background(Color.mSage100)
        }
    }
}

// MARK: - المنيو tab

private struct MenuTab: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    @State private var showAddCategory = false
    @State private var addItemForCategory: MenuCategory? = nil
    @State private var selectedCategoryID: MenuCategory.ID?
    @State private var confirmDeleteRestaurant = false

    private var isArabic: Bool { store.language == .arabic }

    private var activeCategory: MenuCategory? {
        restaurant.categories.first(where: { $0.id == selectedCategoryID }) ?? restaurant.categories.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 9) {
                        MStatTile(value: "\(restaurant.allItems.count)", label: isArabic ? "إجمالي المنتجات" : "Total Items", dark: false)
                        MStatTile(value: "\(restaurant.allItems.filter { !$0.isAvailable }.count)", label: isArabic ? "نفذت الكمية" : "Out of Stock", dark: false)
                    }

                    if restaurant.categories.isEmpty {
                        emptyCategoriesState
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(restaurant.categories) { category in
                                    MFilterChip(
                                        label: "\(category.letter) · \(category.displayName(store.language)) · \(category.items.count)",
                                        selected: activeCategory?.id == category.id,
                                        action: { selectedCategoryID = category.id }
                                    )
                                }
                            }
                        }

                        HStack {
                            Text(isArabic ? "التصنيفات" : "Categories")
                                .font(.plexArabicHeavy(16))
                                .foregroundStyle(Color.mInk)
                            Spacer()
                            if let category = activeCategory {
                                Button {
                                    addItemForCategory = category
                                } label: {
                                    Text(isArabic ? "+ أضف منتج" : "+ Add Item")
                                        .font(.plexArabic(12.5, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 9)
                                        .background(Color.mAccent)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let category = activeCategory {
                            VStack(spacing: 10) {
                                ForEach(category.items) { item in
                                    ProductCard(restaurantID: restaurant.id, categoryID: category.id, item: item)
                                }
                            }

                            Button(role: .destructive) {
                                deleteCategory(category)
                            } label: {
                                Label(isArabic ? "حذف هذا التصنيف" : "Delete This Category", systemImage: "trash")
                                    .font(.plexArabic(12.5, weight: .semibold))
                            }
                            .padding(.top, 4)
                        }
                    }

                    Text(isArabic
                         ? "يتكوّن الرمز تلقائيًا من حرف التصنيف مع أول رقم متاح، ويبقى ثابتًا دائمًا حتى لو تغيّر الاسم أو السعر."
                         : "The code is generated automatically from the category letter plus the first free number, and stays fixed even if the name or price changes.")
                        .font(.plexArabic(12.5))
                        .foregroundStyle(Color.mAccent900)
                        .multilineTextAlignment(.trailing)
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .background(Color.mAccent100)
                        .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))

                    Button(role: .destructive) {
                        confirmDeleteRestaurant = true
                    } label: {
                        Text(isArabic ? "حذف المطعم نهائيًا" : "Delete Restaurant Permanently")
                            .font(.plexArabic(13.5, weight: .semibold))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "المنيو" : "Menu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddCategory = true } label: { Image(systemName: "plus") }
                }
            }
            .confirmationDialog(
                isArabic
                    ? "حذف \(restaurant.displayName(store.language)) نهائيًا؟ كل التصنيفات والمنتجات تُحذف معه، ولا يمكن التراجع."
                    : "Permanently delete \(restaurant.displayName(store.language))? All its categories and items go with it — this can't be undone.",
                isPresented: $confirmDeleteRestaurant,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف نهائيًا" : "Delete Permanently", role: .destructive) {
                    Task { await store.deleteRestaurant(restaurant.id) }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet(restaurantID: restaurant.id)
            }
            .sheet(item: $addItemForCategory) { category in
                AddItemSheet(restaurantID: restaurant.id, category: category)
            }
        }
    }

    private var emptyCategoriesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 30))
                .foregroundStyle(Color.mInkFaint)
            Text(isArabic ? "ابدئي بإضافة تصنيف، مثل «مشروبات ساخنة»." : "Start by adding a category, like \"Hot Drinks.\"")
                .font(.plexArabic(13))
                .foregroundStyle(Color.mInkSecondary)
                .multilineTextAlignment(.center)
            Button { showAddCategory = true } label: {
                Text(isArabic ? "أضف تصنيفًا" : "Add a Category")
            }
            .buttonStyle(.mPrimary(.mAccent, fullWidth: false))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func deleteCategory(_ category: MenuCategory) {
        Task {
            await store.deleteCategory(category.id)
            if selectedCategoryID == category.id { selectedCategoryID = nil }
        }
    }
}

// MARK: - Product card (inline price + availability)

private struct ProductCard: View {
    @Environment(AppStore.self) private var store
    let restaurantID: UUID
    let categoryID: UUID
    let item: MenuItem
    @State private var priceValue: Double = 0
    @State private var isAvailable: Bool = true
    @State private var priceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.mSurface2 }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                CodeChip(code: item.code)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName(store.language))
                        .font(.plexArabicHeavy(14))
                        .foregroundStyle(Color.mInk)
                    if store.language == .arabic {
                        Text(item.name)
                            .font(.plexMono(10.5))
                            .foregroundStyle(Color.mInkFaint)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }

                Spacer()

                MAvailabilityToggle(isOn: Binding(
                    get: { isAvailable },
                    set: { newValue in
                        isAvailable = newValue
                        Task { await store.toggleAvailability(itemID: item.id, categoryID: categoryID, restaurantID: restaurantID) }
                    }
                ))
            }

            Divider().overlay(Color.mHairline)

            HStack {
                Text(store.language == .arabic ? "السعر" : "Price")
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInkTertiary)
                MPriceInputField(value: Binding(
                    get: { priceValue },
                    set: { newValue in
                        priceValue = newValue
                        priceTask?.cancel()
                        priceTask = Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !Task.isCancelled else { return }
                            await store.updatePrice(itemID: item.id, categoryID: categoryID, restaurantID: restaurantID, price: newValue)
                        }
                    }
                ))
                Spacer()
                MTag(
                    text: isAvailable ? (store.language == .arabic ? "متوفر" : "Available") : (store.language == .arabic ? "نفذت الكمية" : "Out of Stock"),
                    style: isAvailable ? .tinted(.mSage100, .mSage800) : .neutral
                )
            }
        }
        .padding(14)
        .opacity(isAvailable ? 1 : 0.7)
        .mCardStyle()
        .onAppear {
            priceValue = item.price
            isAvailable = item.isAvailable
        }
    }
}

// MARK: - مطعمي tab

private struct VenueTab: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    @State private var showHoursEditor = false
    @State private var showLocationPicker = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var isUploadingPhoto = false
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var isSaving = false
    @State private var toast: String? = nil

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    statusCard

                    Text(isArabic ? "بيانات المتجر" : "Store Details")
                        .font(.plexArabicHeavy(16))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(isArabic ? "متجر واحد لكل حساب. يظهر الشعار للعملاء في الصفحة الرئيسية وأعلى القائمة." : "One store per account. The logo appears to customers on the home page and atop the menu.")
                        .font(.plexArabic(12))
                        .foregroundStyle(Color.mInkSecondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    HStack(spacing: 14) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            PhotoUploadSlot(imageURL: restaurant.imageURL, isUploading: isUploadingPhoto, size: 96, radius: MTheme.radiusLogo, tint: .mSage100)
                        }
                        .buttonStyle(.plain)
                        Text(isArabic ? "اسحب الشعار هنا أو اضغط للاختيار. يفضّل استخدام صورة مربعة وواضحة." : "Drag your logo here or tap to choose. A clear square image works best.")
                            .font(.plexArabic(11.5))
                            .foregroundStyle(Color.mInkTertiary)
                            .multilineTextAlignment(.trailing)
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                            isUploadingPhoto = true
                            await store.uploadRestaurantImage(restaurant.id, imageData: data)
                            isUploadingPhoto = false
                        }
                    }

                    MFormField(label: isArabic ? "اسم المتجر" : "Store name") {
                        TextField(isArabic ? "اسم المتجر" : "Store name", text: $name).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "جوال المتجر" : "Store phone") {
                        TextField("05xxxxxxxx", text: $phone).keyboardType(.phonePad).mFieldStyle()
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    MFormField(label: isArabic ? "العنوان" : "Address") {
                        TextField(isArabic ? "العنوان" : "Address", text: $address).mFieldStyle()
                    }

                    Button {
                        showHoursEditor = true
                    } label: {
                        infoRow(icon: "clock", title: isArabic ? "أوقات الدوام" : "Hours", value: hoursText)
                    }
                    Button {
                        showLocationPicker = true
                    } label: {
                        infoRow(icon: "mappin.and.ellipse", title: isArabic ? "الموقع" : "Location",
                                value: restaurant.hasLocation ? (isArabic ? "محدَّد" : "Set") : (isArabic ? "لم يُحدَّد" : "Not set"),
                                valueColor: restaurant.hasLocation ? .mSage700 : .mInkFaint)
                    }

                    Button {
                        save()
                    } label: {
                        if isSaving { ProgressView().tint(.white) } else { Text(isArabic ? "حفظ بيانات المتجر" : "Save Store Details") }
                    }
                    .buttonStyle(.mPrimary(.mSage))
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "مطعمي" : "My Store")
            .onAppear {
                name = restaurant.displayName(store.language)
                phone = ""
                address = ""
            }
            .sheet(isPresented: $showHoursEditor) { HoursEditSheet(restaurant: restaurant) }
            .sheet(isPresented: $showLocationPicker) { RestaurantLocationPickerView(restaurant: restaurant) }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.plexArabic(13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 11)
                        .background(Color.mInk)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    /// Three states, not two. `isPublished` alone can't tell a declined
    /// application from one still in the queue — both are unpublished — so a
    /// rejected vendor used to read "a response usually comes within a business
    /// day" forever, for a decision that had already been made.
    private var statusCard: some View {
        let isRejected = !restaurant.isPublished && restaurant.status == .rejected

        let title: String = if restaurant.isPublished {
            isArabic ? "متجرك منشور للعملاء" : "Your store is live for customers"
        } else if isRejected {
            isArabic ? "لم يُعتمد الطلب" : "Application not approved"
        } else {
            isArabic ? "الطلب تحت المراجعة" : "Your request is under review"
        }

        let detail: String = if restaurant.isPublished {
            isArabic ? "تصل تعديلات الأسعار والتوفّر إلى العملاء لحظيًا." : "Price and availability edits reach customers instantly."
        } else if isRejected {
            isArabic ? "متجرك لا يظهر للعملاء. راجع بياناتك وقائمتك، ثم تواصل مع الإدارة لإعادة النظر." : "Your store isn't visible to customers. Review your details and menu, then contact admin to have it reconsidered."
        } else {
            isArabic ? "تراجع الإدارة بياناتك، والرد عادةً خلال يوم عمل." : "Admin is reviewing your details — a response usually comes within a business day."
        }

        return HStack {
            VStack(alignment: .trailing, spacing: 4) {
                Text(title).font(.plexArabicHeavy(14))
                Text(detail)
                    .font(.plexArabic(11.5))
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .foregroundStyle(restaurant.isPublished ? Color.mSage900 : Color.mAccent900)
        .padding(15)
        .background(restaurant.isPublished ? Color.mSage100 : (isRejected ? Color.mAccent200 : Color.mAccent100))
        .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
    }

    private func infoRow(icon: String, title: String, value: String, valueColor: Color = .mInkSecondary) -> some View {
        HStack {
            Image(systemName: "chevron.left").font(.system(size: 11)).foregroundStyle(Color.mInkFaint)
            Text(value).font(.plexArabic(12.5)).foregroundStyle(valueColor)
            Spacer()
            Text(title).font(.plexArabic(13.5)).foregroundStyle(Color.mInk)
            Image(systemName: icon).foregroundStyle(Color.mInkSecondary)
        }
        .padding(15)
        .background(Color.mSurface)
        .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MTheme.radiusSmall, style: .continuous).strokeBorder(Color.mLine, lineWidth: 1))
    }

    private var hoursText: String {
        guard let opens = restaurant.opensAt, let closes = restaurant.closesAt else {
            return isArabic ? "لم تُحدَّد" : "Not set"
        }
        return "\(opens) – \(closes)"
    }

    private func save() {
        isSaving = true
        Task {
            // Name/phone/address aren't yet backed by dedicated columns on
            // `restaurants` beyond name — this saves what the schema
            // currently supports (hours/location have their own sheets).
            isSaving = false
            withAnimation { toast = isArabic ? "تم حفظ بيانات المتجر" : "Store details saved" }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - حسابي tab (owner's own profile)

private struct AccountTab: View {
    @Environment(AppStore.self) private var store
    @State private var showCreateRestaurant = false
    @State private var confirmDeleteAccount = false

    private var isArabic: Bool { store.language == .arabic }
    private var initial: String { (store.currentUserEmail?.trimmingCharacters(in: .whitespaces).first).map(String.init)?.uppercased() ?? "؟" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .trailing, spacing: 16) {
                    HStack(spacing: 12) {
                        Text(store.currentUserEmail ?? "")
                            .font(.plexMono(11.5))
                            .foregroundStyle(Color.mInkSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        ZStack {
                            Circle().fill(.white).frame(width: 54, height: 54)
                            Text(initial).font(.plexMono(20, weight: .heavy)).foregroundStyle(Color.mSage800)
                        }
                    }
                    .padding(16)
                    .background(Color.mSage100)
                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))

                    if store.myRestaurants.count > 1 {
                        Text(isArabic ? "مطاعمي" : "My Restaurants")
                            .font(.plexArabicHeavy(14))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        VStack(spacing: 8) {
                            ForEach(store.myRestaurants) { restaurant in
                                Button {
                                    store.selectedRestaurantID = restaurant.id
                                } label: {
                                    HStack {
                                        if store.selectedRestaurantID == restaurant.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mSage700)
                                        }
                                        Spacer()
                                        Text(restaurant.displayName(store.language))
                                            .font(.plexArabic(13.5, weight: .medium))
                                            .foregroundStyle(Color.mInk)
                                    }
                                    .padding(13)
                                    .background(Color.mSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: MTheme.radiusSmall, style: .continuous).strokeBorder(Color.mLine, lineWidth: 1))
                                }
                            }
                        }
                    }

                    Button { showCreateRestaurant = true } label: {
                        Text(isArabic ? "إضافة مطعم جديد" : "Add Another Restaurant")
                    }
                    .buttonStyle(.mSecondary())

                    Button(role: .destructive) {
                        Task { await store.signOut() }
                    } label: {
                        Text(isArabic ? "تسجيل الخروج" : "Sign Out")
                    }
                    .buttonStyle(.mSecondary())
                    .padding(.top, 4)

                    Button {
                        confirmDeleteAccount = true
                    } label: {
                        Text(isArabic ? "حذف الحساب نهائيًا" : "Delete Account Permanently")
                            .font(.plexArabic(12.5, weight: .semibold))
                            .foregroundStyle(Color.mInkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(.plexArabic(12))
                            .foregroundStyle(Color.mAccent800)
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "حسابي" : "Account")
            .sheet(isPresented: $showCreateRestaurant) {
                CreateRestaurantSheet(onCreated: { newID in store.selectedRestaurantID = newID })
            }
            .confirmationDialog(
                isArabic
                    ? "حذف حسابك نهائيًا؟ كل بياناتك ومطاعمك تُحذف معه، ولا يمكن التراجع."
                    : "Permanently delete your account? All your data and restaurants go with it — this can't be undone.",
                isPresented: $confirmDeleteAccount,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف نهائيًا" : "Delete Permanently", role: .destructive) {
                    Task {
                        do { try await store.deleteAccount() } catch { store.errorMessage = error.localizedDescription }
                    }
                }
            }
        }
    }
}

// MARK: - Photo upload slot (shared)

struct PhotoUploadSlot: View {
    let imageURL: String?
    var isUploading: Bool = false
    var size: CGFloat = 96
    var radius: CGFloat = MTheme.radiusLogo
    var tint: Color = .mSurface2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint)
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.clear }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(Color.mInkFaint)
            }
            if isUploading {
                Color.black.opacity(0.25)
                ProgressView().tint(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Hours Edit Sheet

private struct HoursEditSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurant: Restaurant
    @State private var opensAt: Date
    @State private var closesAt: Date
    @State private var isSaving = false

    private var isArabic: Bool { store.language == .arabic }

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        _opensAt = State(initialValue: Self.parseTime(restaurant.opensAt, defaultHour: 9))
        _closesAt = State(initialValue: Self.parseTime(restaurant.closesAt, defaultHour: 23))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MFormField(label: isArabic ? "وقت الفتح" : "Opens at") {
                        DatePicker("", selection: $opensAt, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.wheel)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    MFormField(label: isArabic ? "وقت الإغلاق" : "Closes at") {
                        DatePicker("", selection: $closesAt, displayedComponents: .hourAndMinute)
                            .labelsHidden().datePickerStyle(.wheel)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "أوقات الدوام" : "Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                MSheetToolbar(
                    isArabic: isArabic,
                    cancelTitle: isArabic ? "إلغاء" : "Cancel",
                    actionTitle: isArabic ? "حفظ" : "Save",
                    actionDisabled: isSaving,
                    tint: .mSage700,
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.updateRestaurantHours(restaurant.id, opensAt: Self.formatTime(opensAt), closesAt: Self.formatTime(closesAt))
                            dismiss()
                        }
                    }
                )
            }
        }
    }

    private static func parseTime(_ s: String?, defaultHour: Int) -> Date {
        if let s, let d = timeFormatter.date(from: s) { return d }
        return Calendar.current.date(bySettingHour: defaultHour, minute: 0, second: 0, of: Date()) ?? Date()
    }
    private static func formatTime(_ date: Date) -> String { timeFormatter.string(from: date) }
    private static let timeFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
}

// MARK: - Create Restaurant Sheet

struct CreateRestaurantSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onCreated: (UUID) -> Void

    @State private var nameAr = ""
    @State private var nameEn = ""
    @State private var type: RestaurantType = .restaurant
    @State private var descriptionAr = ""
    @State private var isSaving = false

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MFormField(label: isArabic ? "الاسم بالعربي" : "Arabic name") {
                        TextField(isArabic ? "مثال: مقهى الرقعي" : "e.g. Al-Ruqaie Café", text: $nameAr).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Al-Ruqaie Café", text: $nameEn).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "النوع" : "Type") {
                        HStack(spacing: 8) {
                            ForEach(RestaurantType.allCases, id: \.self) { t in
                                MFilterChip(label: t.label(store.language), selected: type == t, action: { type = t })
                            }
                        }
                    }
                    MFormField(label: isArabic ? "وصف قصير (اختياري)" : "Short description (optional)") {
                        TextField(isArabic ? "سطر واحد يعرّف بمطعمك" : "One line about your place", text: $descriptionAr, axis: .vertical).mFieldStyle()
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "مطعم جديد" : "New Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                MSheetToolbar(
                    isArabic: isArabic,
                    cancelTitle: isArabic ? "إلغاء" : "Cancel",
                    actionTitle: isArabic ? "إنشاء" : "Create",
                    actionDisabled: (nameAr.isEmpty && nameEn.isEmpty) || isSaving,
                    tint: .mSage700,
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            let finalNameEn = nameEn.isEmpty ? nameAr : nameEn
                            let finalNameAr = nameAr.isEmpty ? nameEn : nameAr
                            if let id = await store.createRestaurant(nameEn: finalNameEn, nameAr: finalNameAr, type: type, descriptionEn: descriptionAr, descriptionAr: descriptionAr) {
                                onCreated(id)
                            }
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Add Category Sheet

private struct AddCategorySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurantID: UUID
    @State private var nameAr = ""
    @State private var nameEn = ""
    @State private var isSaving = false

    private var isArabic: Bool { store.language == .arabic }

    private var nextLetter: String {
        guard let r = store.myRestaurants.first(where: { $0.id == restaurantID }) else { return "A" }
        let usedCount = r.categories.count
        guard usedCount < 26 else { return "?" }
        return String(UnicodeScalar(65 + usedCount)!)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MFormField(label: isArabic ? "الاسم بالعربي" : "Arabic name") {
                        TextField(isArabic ? "مثال: مشروبات ساخنة" : "e.g. Hot Drinks", text: $nameAr).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Hot Drinks", text: $nameEn).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الرمز التلقائي" : "Auto code") {
                        HStack { CodeChip(code: nextLetter, tint: .mSage700); Spacer() }
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "تصنيف جديد" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                MSheetToolbar(
                    isArabic: isArabic,
                    cancelTitle: isArabic ? "إلغاء" : "Cancel",
                    actionTitle: isArabic ? "إضافة" : "Add",
                    actionDisabled: (nameAr.isEmpty && nameEn.isEmpty) || isSaving,
                    tint: .mSage700,
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.addCategory(to: restaurantID, nameEn: nameEn.isEmpty ? nameAr : nameEn, nameAr: nameAr.isEmpty ? nameEn : nameAr)
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Add Item Sheet

private struct AddItemSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurantID: UUID
    let category: MenuCategory
    @State private var nameAr = ""
    @State private var nameEn = ""
    @State private var priceText = ""
    @State private var isSaving = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var previewImage: Image? = nil
    @State private var pendingImageData: Data? = nil

    private var isArabic: Bool { store.language == .arabic }

    private var nextCode: String {
        guard let r = store.myRestaurants.first(where: { $0.id == restaurantID }),
              let c = r.categories.first(where: { $0.id == category.id }) else {
            return category.letter + "01"
        }
        return category.letter + String(format: "%02d", c.items.count + 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            if let previewImage {
                                previewImage.resizable().aspectRatio(contentMode: .fill)
                                    .frame(height: 120).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
                            } else {
                                PhotoUploadSlot(imageURL: nil, size: 120, radius: MTheme.radius)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                pendingImageData = data
                                if let uiImage = UIImage(data: data) { previewImage = Image(uiImage: uiImage) }
                            }
                        }
                    }
                    Text(isArabic
                         ? "صورة الطبق — تظهر للعميل بجانب الرمز مباشرة. أما شعار المتجر فيُضاف من أعلى تبويب مطعمي."
                         : "Dish photo — shown to customers right next to the code. The store logo is added from the My Store tab instead.")
                        .font(.plexArabic(11))
                        .foregroundStyle(Color.mInkFaint)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    MFormField(label: isArabic ? "الاسم بالعربي" : "Arabic name") {
                        TextField(isArabic ? "مثال: لاتيه" : "e.g. Latte", text: $nameAr).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Latte", text: $nameEn).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "السعر (ر.س)" : "Price (SAR)") {
                        TextField("0", text: $priceText).keyboardType(.decimalPad).mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الرمز التلقائي" : "Auto code") {
                        HStack { CodeChip(code: nextCode, tint: .mSage700); Spacer() }
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .navigationTitle(isArabic ? "منتج جديد" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                MSheetToolbar(
                    isArabic: isArabic,
                    cancelTitle: isArabic ? "إلغاء" : "Cancel",
                    actionTitle: isArabic ? "إضافة" : "Add",
                    actionDisabled: (nameAr.isEmpty && nameEn.isEmpty) || isSaving,
                    tint: .mSage700,
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.addItem(to: category.id, restaurantID: restaurantID, nameEn: nameEn.isEmpty ? nameAr : nameEn, nameAr: nameAr.isEmpty ? nameEn : nameAr, price: Double(priceText) ?? 0)
                            if let imageData = pendingImageData,
                               let updated = store.myRestaurants.first(where: { $0.id == restaurantID }),
                               let newItem = updated.categories.first(where: { $0.id == category.id })?.items.last {
                                await store.uploadItemImage(newItem.id, imageData: imageData)
                            }
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}
