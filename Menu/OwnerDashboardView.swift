import SwiftUI
import PhotosUI

/// Manages exactly the restaurant currently selected in AccountView
/// (`store.selectedRestaurantID`) — restaurant switching and creation live
/// there now; this screen is purely "run this one restaurant."
struct OwnerDashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var showAddCategory = false
    @State private var addItemForCategory: MenuCategory? = nil
    @State private var showHoursEditor = false
    @State private var showLocationPicker = false
    @State private var confirmDeleteRestaurant = false

    private var isArabic: Bool { store.language == .arabic }

    var selectedRestaurant: Restaurant? {
        store.myRestaurants.first(where: { $0.id == store.selectedRestaurantID })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let restaurant = selectedRestaurant {
                    List {
                        Section {
                            RestaurantInfoCard(
                                restaurant: restaurant,
                                onEditHours: { showHoursEditor = true },
                                onEditLocation: { showLocationPicker = true }
                            )
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.mBackground)

                        ForEach(restaurant.categories) { category in
                            Section {
                                ForEach(category.items) { item in
                                    OwnerItemRow(
                                        restaurantID: restaurant.id,
                                        categoryID: category.id,
                                        item: item
                                    )
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await store.deleteItem(item.id) }
                                        } label: {
                                            Label(isArabic ? "حذف" : "Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .listRowBackground(Color.mSurface)
                                Button {
                                    addItemForCategory = category
                                } label: {
                                    Label(
                                        isArabic ? "إضافة منتج" : "Add Item",
                                        systemImage: "plus.circle"
                                    )
                                    .font(.plexArabic(13.5, weight: .medium))
                                    .foregroundStyle(Color.mAccentStrong)
                                }
                                .listRowBackground(Color.mSurface)
                            } header: {
                                CategorySectionHeader(category: category, onDelete: {
                                    Task { await store.deleteCategory(category.id) }
                                })
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                confirmDeleteRestaurant = true
                            } label: {
                                Text(isArabic ? "حذف المطعم نهائيًا" : "Delete Restaurant Permanently")
                                    .font(.plexArabic(13.5, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                            }
                        } footer: {
                            Text(isArabic
                                 ? "يحذف المطعم وكل تصنيفاته ومنتجاته نهائيًا، بلا رجعة."
                                 : "Permanently deletes the restaurant and all its categories and items.")
                                .font(.plexArabic(11))
                                .foregroundStyle(Color.mInkFaint)
                        }
                        .listRowBackground(Color.mSurface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
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
                    .sheet(isPresented: $showHoursEditor) {
                        HoursEditSheet(restaurant: restaurant)
                    }
                    .sheet(isPresented: $showLocationPicker) {
                        RestaurantLocationPickerView(restaurant: restaurant)
                    }
                } else {
                    VStack { Spacer(); ProgressView(); Spacer() }
                }
            }
            .navigationTitle(selectedRestaurant?.displayName(store.language) ?? (isArabic ? "لوحتي" : "Dashboard"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddCategory = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(selectedRestaurant == nil)
                }
            }
        }
    }
}

// MARK: - Restaurant Info Card

private struct RestaurantInfoCard: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    var onEditHours: () -> Void
    var onEditLocation: () -> Void

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(restaurant.type.label(store.language))
                    .font(.plexArabic(12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.mAccentSoft)
                    .foregroundStyle(Color.mAccentStrong)
                    .clipShape(Capsule())

                Spacer()

                if restaurant.isPublished {
                    Label(isArabic ? "منشور" : "Published", systemImage: "checkmark.seal.fill")
                        .font(.plexArabic(11.5, weight: .semibold))
                        .foregroundStyle(Color.mGood)
                } else {
                    Label(isArabic ? "قيد المراجعة" : "Under review", systemImage: "clock.fill")
                        .font(.plexArabic(11.5, weight: .semibold))
                        .foregroundStyle(Color.mAccentStrong)
                }
            }

            Divider().overlay(Color.mLine)

            Button(action: onEditHours) {
                HStack {
                    Image(systemName: "clock").foregroundStyle(Color.mInkSoft)
                    Text(isArabic ? "أوقات الدوام" : "Hours")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInk)
                    Spacer()
                    Text(hoursText)
                        .font(.plexMono(12.5, weight: .medium))
                        .foregroundStyle(Color.mInkSoft)
                        .environment(\.layoutDirection, .leftToRight)
                    Image(systemName: "chevron.left").font(.system(size: 11)).foregroundStyle(Color.mInkFaint)
                }
            }

            Button(action: onEditLocation) {
                HStack {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.mInkSoft)
                    Text(isArabic ? "الموقع" : "Location")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInk)
                    Spacer()
                    Text(restaurant.hasLocation
                         ? (isArabic ? "محدَّد" : "Set")
                         : (isArabic ? "لم يُحدَّد" : "Not set"))
                        .font(.plexArabic(12.5))
                        .foregroundStyle(restaurant.hasLocation ? Color.mGood : Color.mInkFaint)
                    Image(systemName: "chevron.left").font(.system(size: 11)).foregroundStyle(Color.mInkFaint)
                }
            }
        }
        .padding(16)
        .background(Color.mSurface)
        .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous).strokeBorder(Color.mLine, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .buttonStyle(.plain)
    }

    private var hoursText: String {
        guard let opens = restaurant.opensAt, let closes = restaurant.closesAt else {
            return isArabic ? "لم تُحدَّد" : "Not set"
        }
        return "\(opens) – \(closes)"
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
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    MFormField(label: isArabic ? "وقت الإغلاق" : "Closes at") {
                        DatePicker("", selection: $closesAt, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
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
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.updateRestaurantHours(
                                restaurant.id,
                                opensAt: Self.formatTime(opensAt),
                                closesAt: Self.formatTime(closesAt)
                            )
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
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
}

// MARK: - Section Header

private struct CategorySectionHeader: View {
    @Environment(AppStore.self) private var store
    let category: MenuCategory
    var onDelete: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        HStack {
            Text(category.letter)
                .font(.plexMono(11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.mAccent)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .environment(\.layoutDirection, .leftToRight)

            Text(category.displayName(store.language))
                .font(.plexArabic(13.5, weight: .semibold))
                .foregroundStyle(Color.mInk)

            Spacer()

            Text("\(category.items.count) \(store.language == .arabic ? "منتج" : "items")")
                .font(.plexArabic(11.5))
                .foregroundStyle(Color.mInkSoft)

            Button {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mInkFaint)
            }
            .confirmationDialog(
                store.language == .arabic
                    ? "حذف هذا التصنيف يحذف كل منتجاته ورموزها نهائيًا."
                    : "Deleting this category permanently removes all its items and codes.",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button(store.language == .arabic ? "حذف التصنيف" : "Delete Category", role: .destructive, action: onDelete)
            }
        }
        .textCase(nil)
    }
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
                        TextField(isArabic ? "مثال: مقهى الرقعي" : "e.g. Al-Ruqaie Café", text: $nameAr)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Al-Ruqaie Café", text: $nameEn)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "النوع" : "Type") {
                        HStack(spacing: 8) {
                            ForEach(RestaurantType.allCases, id: \.self) { t in
                                Button {
                                    type = t
                                } label: {
                                    Text(t.label(store.language))
                                        .font(.plexArabic(12.5, weight: type == t ? .semibold : .regular))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(type == t ? Color.mInk : Color.mSurface)
                                        .foregroundStyle(type == t ? Color.mBackground : Color.mInkSoft)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(type == t ? Color.clear : Color.mLine, lineWidth: 1))
                                }
                            }
                        }
                    }
                    MFormField(label: isArabic ? "وصف قصير (اختياري)" : "Short description (optional)") {
                        TextField(isArabic ? "سطر واحد يعرّف بمطعمك" : "One line about your place", text: $descriptionAr, axis: .vertical)
                            .mFieldStyle()
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
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            let finalNameEn = nameEn.isEmpty ? nameAr : nameEn
                            let finalNameAr = nameAr.isEmpty ? nameEn : nameAr
                            if let id = await store.createRestaurant(
                                nameEn: finalNameEn, nameAr: finalNameAr, type: type,
                                descriptionEn: descriptionAr, descriptionAr: descriptionAr
                            ) {
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

// MARK: - Item Row

private struct OwnerItemRow: View {
    @Environment(AppStore.self) private var store
    let restaurantID: UUID
    let categoryID: UUID
    let item: MenuItem
    @State private var showEditPrice = false

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = item.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.mSurface2
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            CodeChip(code: item.code)
                .opacity(item.isAvailable ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.plexArabic(14, weight: .medium))
                    .foregroundStyle(Color.mInk)

                Button {
                    showEditPrice = true
                } label: {
                    HStack(spacing: 3) {
                        Text(priceText(item.price))
                            .font(.plexMono(12, weight: .semibold))
                            .foregroundStyle(Color.mInk)
                            .environment(\.layoutDirection, .leftToRight)
                        Image(systemName: "pencil")
                            .font(.system(size: 9)).foregroundStyle(Color.mInkSoft)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isAvailable },
                set: { _ in
                    Task {
                        await store.toggleAvailability(
                            itemID: item.id,
                            categoryID: categoryID,
                            restaurantID: restaurantID
                        )
                    }
                }
            ))
            .labelsHidden()
        }
        .sheet(isPresented: $showEditPrice) {
            EditPriceSheet(restaurantID: restaurantID, categoryID: categoryID, item: item)
        }
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
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
                        TextField(isArabic ? "مثال: مشروبات ساخنة" : "e.g. Hot Drinks", text: $nameAr)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Hot Drinks", text: $nameEn)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الرمز التلقائي" : "Auto code") {
                        HStack {
                            CodeChip(code: nextLetter)
                            Spacer()
                        }
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
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.addCategory(
                                to: restaurantID,
                                nameEn: nameEn.isEmpty ? nameAr : nameEn,
                                nameAr: nameAr.isEmpty ? nameEn : nameAr
                            )
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
                            RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous)
                                .fill(Color.mSurface2)
                            if let previewImage {
                                previewImage.resizable().aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
                            } else {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 26))
                                    Text(isArabic ? "أضيفي صورة (اختياري)" : "Add a photo (optional)")
                                        .font(.plexArabic(12))
                                }
                                .foregroundStyle(Color.mInkFaint)
                            }
                        }
                        .frame(height: 120)
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                pendingImageData = data
                                if let uiImage = UIImage(data: data) {
                                    previewImage = Image(uiImage: uiImage)
                                }
                            }
                        }
                    }

                    MFormField(label: isArabic ? "الاسم بالعربي" : "Arabic name") {
                        TextField(isArabic ? "مثال: لاتيه" : "e.g. Latte", text: $nameAr)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الاسم بالإنجليزي" : "English name") {
                        TextField("e.g. Latte", text: $nameEn)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "السعر (ر.س)" : "Price (SAR)") {
                        TextField("0", text: $priceText)
                            .keyboardType(.decimalPad)
                            .mFieldStyle()
                    }
                    MFormField(label: isArabic ? "الرمز التلقائي" : "Auto code") {
                        HStack {
                            CodeChip(code: nextCode)
                            Spacer()
                        }
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
                    onCancel: { dismiss() },
                    onAction: {
                        isSaving = true
                        Task {
                            await store.addItem(
                                to: category.id,
                                restaurantID: restaurantID,
                                nameEn: nameEn.isEmpty ? nameAr : nameEn,
                                nameAr: nameAr.isEmpty ? nameEn : nameAr,
                                price: Double(priceText) ?? 0
                            )
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

// MARK: - Edit Price Sheet

private struct EditPriceSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurantID: UUID
    let categoryID: UUID
    let item: MenuItem
    @State private var priceText = ""
    @State private var isSaving = false

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        CodeChip(code: item.code)
                        Text(item.displayName(store.language))
                            .font(.plexArabic(15, weight: .medium))
                            .foregroundStyle(Color.mInk)
                        Spacer()
                    }
                    MFormField(label: isArabic ? "السعر الجديد (ر.س)" : "New price (SAR)") {
                        TextField("0", text: $priceText)
                            .keyboardType(.decimalPad)
                            .mFieldStyle()
                    }
                }
                .padding(20)
            }
            .background(Color.mBackground)
            .onAppear { priceText = "\(Int(item.price))" }
            .navigationTitle(isArabic ? "تعديل السعر" : "Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                MSheetToolbar(
                    isArabic: isArabic,
                    cancelTitle: isArabic ? "إلغاء" : "Cancel",
                    actionTitle: isArabic ? "حفظ" : "Save",
                    actionDisabled: isSaving,
                    onCancel: { dismiss() },
                    onAction: {
                        guard let price = Double(priceText) else { return }
                        isSaving = true
                        Task {
                            await store.updatePrice(
                                itemID: item.id,
                                categoryID: categoryID,
                                restaurantID: restaurantID,
                                price: price
                            )
                            dismiss()
                        }
                    }
                )
            }
        }
    }
}
