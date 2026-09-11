import SwiftUI

struct OwnerDashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedRestaurantID: UUID? = nil
    @State private var showAddCategory = false
    @State private var addItemForCategory: MenuCategory? = nil

    var selectedRestaurant: Restaurant? {
        store.myRestaurants.first(where: { $0.id == selectedRestaurantID })
    }

    var body: some View {
        NavigationStack {
            if !store.isAuthenticated {
                VendorSignInView()
                    .navigationTitle(store.language == .arabic ? "لوحة التحكم" : "Dashboard")
                    .navigationBarTitleDisplayMode(.large)
            } else {
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
                                    }
                                    Button {
                                        addItemForCategory = category
                                    } label: {
                                        Label(
                                            store.language == .arabic ? "إضافة منتج" : "Add Item",
                                            systemImage: "plus.circle"
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(Color.brand)
                                    }
                                } header: {
                                    CategorySectionHeader(category: category)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    } else {
                        ContentUnavailableView(
                            store.language == .arabic ? "لا توجد مطاعم" : "No Restaurants",
                            systemImage: "fork.knife",
                            description: Text(store.language == .arabic
                                ? "أضف مطعمك الأول من خلال الإعدادات"
                                : "Add your first restaurant in settings")
                        )
                    }
                }
                .navigationTitle(store.language == .arabic ? "لوحة التحكم" : "Dashboard")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddCategory = true } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(selectedRestaurant == nil)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await store.signOut() }
                        } label: {
                            Text(store.language == .arabic ? "خروج" : "Sign Out")
                                .foregroundStyle(.red)
                                .font(.subheadline)
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
                            .font(.subheadline)
                            .fontWeight(selectedRestaurantID == restaurant.id ? .semibold : .regular)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(selectedRestaurantID == restaurant.id ? Color.brand : Color(.secondarySystemBackground))
                            .foregroundStyle(selectedRestaurantID == restaurant.id ? .white : .primary)
                            .clipShape(Capsule())
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

    var body: some View {
        HStack {
            Text(category.letter)
                .font(.system(.caption, design: .monospaced, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.brand)
                .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(category.displayName(store.language))
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(category.items.count) \(store.language == .arabic ? "منتج" : "items")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .textCase(nil)
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
            Text(item.code)
                .font(.system(.callout, design: .monospaced, weight: .black))
                .foregroundStyle(item.isAvailable ? Color.brand : Color(.systemGray3))
                .frame(width: 44, height: 44)
                .background(item.isAvailable ? Color.brandLight : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.subheadline).fontWeight(.medium)

                Button {
                    showEditPrice = true
                } label: {
                    HStack(spacing: 3) {
                        Text(priceText(item.price))
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(Color.brand)
                        Image(systemName: "pencil")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
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
                        Text(nextLetter)
                            .font(.system(.title3, design: .monospaced, weight: .black))
                            .foregroundStyle(Color.brand)
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
                        Text(nextCode)
                            .font(.system(.title3, design: .monospaced, weight: .black))
                            .foregroundStyle(Color.brand)
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
                        Text(item.code)
                            .font(.system(.headline, design: .monospaced, weight: .black))
                            .foregroundStyle(Color.brand)
                        Text(item.displayName(store.language))
                            .fontWeight(.medium)
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

// MARK: - Vendor Sign In View

private struct VendorSignInView: View {
    @Environment(AppStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorText: String? = nil

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 12)

                // Icon + Title
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.brandLight)
                            .frame(width: 88, height: 88)
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.brand)
                    }
                    .shadow(color: Color.brand.opacity(0.15), radius: 12, x: 0, y: 6)

                    Text(isArabic ? "لوحة تحكم صاحب المطعم" : "Vendor Dashboard")
                        .font(.title2).fontWeight(.bold)

                    Text(isArabic
                         ? "سجّل دخولك لإدارة منيوك"
                         : "Sign in to manage your menu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Form
                VStack(spacing: 12) {
                    TextField(isArabic ? "البريد الإلكتروني" : "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField(isArabic ? "كلمة المرور" : "Password", text: $password)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Error
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Action button
                Button {
                    Task {
                        isLoading = true
                        errorText = nil
                        do {
                            if isSignUp {
                                try await store.signUp(email: email, password: password)
                            } else {
                                try await store.signIn(email: email, password: password)
                            }
                        } catch {
                            errorText = error.localizedDescription
                        }
                        isLoading = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        }
                        Text(isSignUp
                             ? (isArabic ? "إنشاء حساب" : "Create Account")
                             : (isArabic ? "تسجيل الدخول" : "Sign In"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(email.isEmpty || password.isEmpty || isLoading
                                ? Color.brand.opacity(0.4) : Color.brand)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(email.isEmpty || password.isEmpty || isLoading)

                // Toggle sign-in / sign-up
                Button {
                    isSignUp.toggle()
                    errorText = nil
                } label: {
                    Text(isSignUp
                         ? (isArabic ? "لديك حساب؟ سجّل الدخول" : "Already have an account? Sign In")
                         : (isArabic ? "لا حساب لديك؟ أنشئ حسابًا" : "No account? Create one"))
                        .font(.subheadline)
                        .foregroundStyle(Color.brand)
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 28)
        }
    }
}
