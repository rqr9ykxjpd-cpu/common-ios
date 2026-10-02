import Foundation
import Supabase

extension SupabaseProductService: PlaceActivityWatching {
    /// `place_activity` damgaları. Mesaj akışı gibi: bağlantı koparsa katlanan
    /// beklemeyle yeniden bağlanır, görev iptal edilene kadar sürer.
    func placeActivityStream() -> AsyncStream<UUID> {
        AsyncStream { continuation in
            let task = Task {
                let ilkBekleme: UInt64 = 1_000_000_000
                let enUzunBekleme: UInt64 = 30_000_000_000
                var bekleme = ilkBekleme
                while !Task.isCancelled {
                    let channel = client.channel("kim-nerede-\(UUID().uuidString.prefix(8).lowercased())")
                    let eklenen = channel.postgresChange(InsertAction.self, schema: "public", table: "place_activity")
                    let guncellenen = channel.postgresChange(UpdateAction.self, schema: "public", table: "place_activity")
                    do {
                        try await channel.subscribeWithError()
                        bekleme = ilkBekleme
                        await withTaskGroup(of: Void.self) { grup in
                            grup.addTask {
                                for await olay in eklenen {
                                    if let row = try? olay.decodeRecord(as: PlaceActivityRow.self, decoder: Self.decoder) {
                                        continuation.yield(row.placeID)
                                    }
                                }
                            }
                            grup.addTask {
                                for await olay in guncellenen {
                                    if let row = try? olay.decodeRecord(as: PlaceActivityRow.self, decoder: Self.decoder) {
                                        continuation.yield(row.placeID)
                                    }
                                }
                            }
                        }
                    } catch {
                        // Bağlanılamadı; beklemeden sonra yeniden denenir.
                    }
                    await client.removeChannel(channel)
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: bekleme)
                    bekleme = min(bekleme * 2, enUzunBekleme)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private struct PlaceActivityRow: Decodable {
    let placeID: UUID
    enum CodingKeys: String, CodingKey { case placeID = "place_id" }
}
