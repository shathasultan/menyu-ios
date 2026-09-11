import SwiftUI
import MapKit

/// Lets a vendor drop/drag a pin for their restaurant's location. Defaults to
/// centering on Riyadh since that's the only city in scope right now.
struct RestaurantLocationPickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurant: Restaurant

    @State private var position: MapCameraPosition
    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var isSaving = false

    private static let riyadhCenter = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)

    private var isArabic: Bool { store.language == .arabic }

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        let coord = CLLocationCoordinate2D(
            latitude: restaurant.latitude ?? Self.riyadhCenter.latitude,
            longitude: restaurant.longitude ?? Self.riyadhCenter.longitude
        )
        _pinCoordinate = State(initialValue: coord)
        _position = State(initialValue: .region(
            MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06))
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $position) {
                        Marker(isArabic ? "موقع المطعم" : "Restaurant", coordinate: pinCoordinate)
                            .tint(Color.mAccentStrong)
                    }
                    .onTapGesture { screenPoint in
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            pinCoordinate = coordinate
                        }
                    }
                }

                VStack(spacing: 12) {
                    Text(isArabic
                         ? "انقري على الخريطة لتحديد موقع مطعمك"
                         : "Tap the map to set your restaurant's location")
                        .font(.plexArabic(12.5))
                        .foregroundStyle(Color.mInkSoft)
                        .multilineTextAlignment(.center)

                    Button {
                        isSaving = true
                        Task {
                            await store.updateRestaurantLocation(
                                restaurant.id,
                                latitude: pinCoordinate.latitude,
                                longitude: pinCoordinate.longitude
                            )
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white).scaleEffect(0.85) }
                            Text(isArabic ? "حفظ الموقع" : "Save Location")
                        }
                        .font(.plexArabic(14.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.mAccent)
                        .foregroundStyle(Color.mAccentInk)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isSaving)
                }
                .padding(16)
                .background(Color.mBackground)
            }
            .navigationTitle(isArabic ? "موقع المطعم" : "Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") { dismiss() }
                        .font(.plexArabic(14))
                        .foregroundStyle(Color.mInkSoft)
                }
            }
        }
    }
}
