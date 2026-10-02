import Foundation
import Supabase

extension SupabaseProductService: PresenceReporting {
    func markOffline() async {
        guard currentUserID != nil else { return }
        _ = try? await client.rpc("mark_offline").execute()
    }
}
