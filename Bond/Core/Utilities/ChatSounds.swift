import AudioToolbox

/// Mesaj sesleri, iPhone Mesajlar'daki gibi: gönderince kısa "vınn", açık
/// sohbete mesaj gelince kısa bir ton. Sistem sesi olarak çalınıyor: zil
/// sesi düzeyinde, sessiz moddayken hiç çalmıyor.
enum ChatSounds {
    static func sent() { AudioServicesPlaySystemSound(1004) }
    static func received() { AudioServicesPlaySystemSound(1003) }
}
