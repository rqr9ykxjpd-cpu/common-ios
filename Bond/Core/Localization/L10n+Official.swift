import Foundation

extension L10n {
    /// Resmi Common hesabı (bkz. `OfficialAccount`).
    enum Official {
        /// Bölüm ve sınıf yerine yazan satır.
        static var line: String { String(localized: "line", table: "Official") }
    }
}
