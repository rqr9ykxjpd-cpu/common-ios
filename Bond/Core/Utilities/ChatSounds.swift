import AudioToolbox

/// Mesaj sesleri, iPhone Mesajlar'daki gibi: gönderince kısa "vınn", açık
/// sohbete mesaj gelince kısa bir ton.
enum ChatSounds {
    /// Sistem sesi: zil düzeyinde, sessiz moddayken hiç çalmıyor (dokunuşu
    /// gönderen ekran ayrıca veriyor).
    static func sent() { AudioServicesPlaySystemSound(1004) }

    /// Uyarı sesi: zil açıkken ton, sessizdeyken titreşim; Ayarlar'daki
    /// "Sessiz modda titret" tercihine uyar. Gelen mesaj Mesajlar'daki gibi
    /// sessizde de hissedilsin diye.
    static func received() { AudioServicesPlayAlertSound(1003) }
}
