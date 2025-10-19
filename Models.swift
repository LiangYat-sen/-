import Foundation

// Main data models

struct Leg: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var flightNo: String = ""
    var dep: String = ""
    var depName: String = ""
    var depTime: String = "" // 4-digit "HHmm"
    var arr: String = ""
    var arrName: String = ""
    var arrTime: String = "" // 4-digit "HHmm"
}

struct CandidateItinerary: Codable, Identifiable {
    var id: UUID = UUID()
    var legs: [Leg]
    var totalMinutes: Int?
    var price: Int
}

struct ItineraryItem: Codable, Identifiable {
    var id: String
    var createdAt: TimeInterval
    var legs: [Leg]
    var price: Int
    var totalMinutes: Int?
    var norm: NormalizedResult?
}

struct HistoryItem: Codable, Identifiable {
    var id: String
    var createdAt: TimeInterval
    var completedAt: TimeInterval
    var legs: [Leg]
    var price: Int
    var totalMinutes: Int?
    var norm: NormalizedResult?
}

struct NormalizedLeg: Codable {
    var depM: Int
    var arrM: Int
    var depAbs: Int
    var arrAbs: Int
    var depDayOffset: Int
    var arrDayOffset: Int
}

struct NormalizedResult: Codable {
    var legsAbs: [NormalizedLeg]
    var totalMinutes: Int
}