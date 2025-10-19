import Foundation

class StorageManager {
    static let shared = StorageManager()
    private init() {}

    private let keyItineraries = "hx_air_itineraries_v1"
    private let keyHistory = "hx_air_history_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadItineraries() -> [ItineraryItem] {
        guard let data = UserDefaults.standard.data(forKey: keyItineraries) else { return [] }
        return (try? decoder.decode([ItineraryItem].self, from: data)) ?? []
    }

    func saveItineraries(_ arr: [ItineraryItem]) {
        if let data = try? encoder.encode(arr) {
            UserDefaults.standard.set(data, forKey: keyItineraries)
        }
    }

    func loadHistory() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: keyHistory) else { return [] }
        return (try? decoder.decode([HistoryItem].self, from: data)) ?? []
    }

    func saveHistory(_ arr: [HistoryItem]) {
        if let data = try? encoder.encode(arr) {
            UserDefaults.standard.set(data, forKey: keyHistory)
        }
    }
}