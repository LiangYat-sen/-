import Foundation

struct Utils {
    static func parseHM(_ hm: String) -> Int? {
        let s = hm.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: #"^\d{4}$"#, options: .regularExpression) == nil {
            return nil
        }
        let hhStr = String(s.prefix(2))
        let mmStr = String(s.suffix(2))
        guard let hh = Int(hhStr), let mm = Int(mmStr) else { return nil }
        return hh * 60 + mm
    }

    static func hmFromMinutesOfDay(_ mins: Int) -> String {
        let m = ((mins % 1440) + 1440) % 1440
        let hh = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", hh, mm)
    }
}