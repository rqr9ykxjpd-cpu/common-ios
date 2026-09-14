import SwiftUI

/// Feed/story’de pp’ye basınca açılan **kişi kartı**.
/// Fotoğraf destesi yalnızca fotoğraf; eşleşme isteği karttaki düğmeden gider.
struct ProfilePhotoStackView: View {
    let profile: StudentProfile
    var showsClose = true

    var body: some View {
        SocialPersonDetailView(profile: profile, place: nil, showsClose: showsClose)
    }
}
