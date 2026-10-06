import Foundation

/// Resmi Common hesabı (@common). Sunucuda bu kullanıcı adını yalnızca bu
/// hesap alabiliyor (20261006020000_official_common_account). Bölüm, sınıf,
/// doğum tarihi ve ilgi alanı bu hesapta sorulmuyor ve gösterilmiyor; yerine
/// "Resmi Common hesabı" yazıyor (sunucu: 20261006060000).
enum OfficialAccount {
    static let id = UUID(uuidString: "0f10b6c0-1f30-4ec0-9103-365cc005fe3b")!
}
