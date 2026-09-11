import SwiftUI

struct OwnerDashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedRestaurantID: UUID? = nil
    @State private var showAddCategory = false
    @State private var addItemForCategory: MenuCategory? = nil
    @State private var showCreateRestaurant = false

    var selectedRestaurant: Restaurant? {
        store.myRestaurants.first(where: { $0.id == selectedRestaurantID })
    }

    var body: some View {
        NavigationStack {
                VStack(spacing: 0) {
                    restaurantPicker
                    Divider()

                    if store.isLoading && store.myRestaurants.isEmpty {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if let restaurant = selectedRestaurant {
                        List {
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
                                                Label(store.language == .arabic ? "حذف" : "Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.mSurface)
                                    Button {
                                        addItemForCategory = category
                                    } label: {
                                        Label(
                                            store.language == .arabic ? "إضافة منتج" : "Add Item",
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
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .background(Color.mBackground)
                    } else {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                .navigationTitle(store.language == .arabic ? "لوحة التحكم" : "Dashboard")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showAddCategory = true
                            } label: {
                                Label(store.language == .arabic ? "تصنيف جديد" : "New Category", systemImage: "square.grid.2x2")
                            }
                            .disabled(selectedRestaurant == nil)

                            Button {
                                showCreateRestaurant = true
                            } label: {
                                Label(store.language == .arabic ? "مطعم جديد" : "New Restaurant", systemImage: "storefront")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await store.signOut() }
                        } label: {
                            Text(store.language == .arabic ? "خروج" : "Sign Out")
                                .foregroundStyle(Color.mBad)
                                .font(.plexArabic(13.5))
                        }
                    }
                }
                .onAppear {
                    if selectedRestaurantID == nil {
                        selectedRestaurantID = store.myRestaurants.first?.id
                    }
                }
                .onChange(of: store.myRestaurants.count) { _, _ in
                    if selectedRestaurantID == nil {
                        selectedRestaurantID = store.myRestaurants.first?.id
                    }
                }
                .sheet(isPresented: $showAddCategory) {
                    if let restaurant = selectedRestaurant {
                        AddCategorySheet(restaurantID: restaurant.id)
                    }
                }
                .sheet(item: $addItemForCategory) { category in
                    if let restaurant = selectedRestaurant {
                        AddItemSheet(restaurantID: restaurant.id, category: category)
                    }
                }
                .sheet(isPresented: $showCreateRestaurant) {
                    CreateRestaurantSheet(onCreated: { newID in
                        selectedRestaurantID = newID
                    })
                }
        }
    }

    private var restaurantPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.myRestaurants) { restaurant in
                    Button {
                        selectedRestaurantID = restaurant.id
                    } label: {
                        Text(restaurant.displayName(store.language))
                            .font(.plexArabic(13, weight: selectedRestaurantID == restaurant.id ? .semibold : .regular))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(selectedRestaurantID == restaurant.id ? Color.mInk : Color.mSurface)
                            .foregroundStyle(selectedRestaurantID == restaurant.id ? Color.mBackground : Color.mInkSoft)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(selectedRestaurantID == restaurant.id ? Color.clear : Color.mLine, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
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
            Form {
                Section(isArabic ? "اسم المطعم" : "Restaurant Name") {
                    TextField(isArabic ? "الاسم بالعربي" : "Arabic name", text: $nameAr)
                    TextField(isArabic ? "الاسم بالإنجليزي" : "English name", text: $nameEn)
                }

                Section(isArabic ? "النوع" : "Type") {
                    Picker(isArabic ? "النوع" : "Type", selection: $type) {
                        ForEach(RestaurantType.allCases, id: \.self) { t in
                            Text(t.label(store.language)).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(isArabic ? "وصف قصير (اختياري)" : "Short description (optional)") {
                    TextField(isArabic ? "سطر واحد يعرّف بمطعمك" : "One line about your place", text: $descriptionAr, axis: .vertical)
                }
            }
            .navigationTitle(isArabic ? "مطعم جديد" : "New Restaurant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isArabic ? "إنشاء" : "Create") {
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
                    .fontWeight(.semibold)
                    .disabled((nameAr.isEmpty && nameEn.isEmpty) || isSaving)
                }
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

    private var nextLetter: String {
        guard let r = store.myRestaurants.first(where: { $0.id == restaurantID }) else { return "A" }
        let usedCount = r.categories.count
        guard usedCount < 26 else { return "?" }
        return String(UnicodeScalar(65 + usedCount)!)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.language == .arabic ? "اسم التصنيف" : "Category Name") {
                    TextField(store.language == .arabic ? "الاسم بالعربي" : "Arabic name", text: $nameAr)
                    TextField(store.language == .arabic ? "الاسم بالإنجليزي" : "English name", text: $nameEn)
                }

                Section(store.language == .arabic ? "الرمز التلقائي" : "Auto Code") {
                    HStack {
                        Text(store.language == .arabic ? "حرف التصنيف" : "Category letter")
                        Spacer()
                        CodeChip(code: nextLetter)
                    }
                }
            }
            .navigationTitle(store.language == .arabic ? "تصنيف جديد" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.language == .arabic ? "إلغاء" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.language == .arabic ? "إضافة" : "Add") {
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
                    .fontWeight(.semibold)
                    .disabled(nameAr.isEmpty && nameEn.isEmpty || isSaving)
                }
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

    private var nextCode: String {
        guard let r = store.myRestaurants.first(where: { $0.id == restaurantID }),
              let c = r.categories.first(where: { $0.id == category.id }) else {
            return category.letter + "01"
        }
        return category.letter + String(format: "%02d", c.items.count + 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.language == .arabic ? "بيانات المنتج" : "Item Details") {
                    TextField(store.language == .arabic ? "الاسم بالعربي" : "Arabic name", text: $nameAr)
                    TextField(store.language == .arabic ? "الاسم بالإنجليزي" : "English name", text: $nameEn)
                    HStack {
                        TextField(store.language == .arabic ? "السعر" : "Price", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text(store.language == .arabic ? "ر.س" : "SAR")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(store.language == .arabic ? "الرمز التلقائي" : "Auto Code") {
                    HStack {
                        Text(store.language == .arabic ? "رمز المنتج الجديد" : "New item code")
                        Spacer()
                        CodeChip(code: nextCode)
                    }
                }
            }
            .navigationTitle(store.language == .arabic ? "منتج جديد" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.language == .arabic ? "إلغاء" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.language == .arabic ? "إضافة" : "Add") {
                        isSaving = true
                        Task {
                            await store.addItem(
                                to: category.id,
                                restaurantID: restaurantID,
                                nameEn: nameEn.isEmpty ? nameAr : nameEn,
                                nameAr: nameAr.isEmpty ? nameEn : nameAr,
                                price: Double(priceText) ?? 0
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(nameAr.isEmpty && nameEn.isEmpty || isSaving)
                }
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        CodeChip(code: item.code)
                        Text(item.displayName(store.language))
                            .font(.plexArabic(14, weight: .medium))
                    }
                }

                Section(store.language == .arabic ? "السعر الجديد (ر.س)" : "New Price (SAR)") {
                    TextField(store.language == .arabic ? "السعر" : "Price", text: $priceText)
                        .keyboardType(.decimalPad)
                }
            }
            .onAppear { priceText = "\(Int(item.price))" }
            .navigationTitle(store.language == .arabic ? "تعديل السعر" : "Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.language == .arabic ? "إلغاء" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.language == .arabic ? "حفظ" : "Save") {
                        if let price = Double(priceText) {
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
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }
}

