import Foundation

struct CSVParser {
    static func parse(text: String) -> [([String: String], [Leg])] {
        var flights: [([String: String], [Leg])] = []
        let lines = text.components(separatedBy: CharacterSet.newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard lines.count >= 1 else { return flights }
        let rows = Array(lines.dropFirst())

        for (idx, line) in rows.enumerated() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            var obj: [String: String] = [:]
            func col(_ i: Int) -> String { (i < cols.count) ? cols[i] : "" }
            obj["航班号"] = col(0); obj["适用星期"] = col(1)
            obj["出发机场_raw"] = col(2); obj["出发机场名称_raw"] = col(3)
            obj["出发时间_raw"] = col(4); obj["到达时间_raw"] = col(5)
            obj["中转机场_raw"] = col(6); obj["中转机场名称_raw"] = col(7)
            obj["中转出发时间_raw"] = col(8); obj["中转到达时间_raw"] = col(9)
            obj["到达机场_raw"] = col(10); obj["到达机场名称_raw"] = col(11)

            var iataTokens: [(code: String, index: Int, raw: String)] = []
            var timeTokens: [(t: String, index: Int)] = []
            for (i, c) in cols.enumerated() {
                if c.isEmpty { continue }
                let up = c.uppercased()
                if up.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil {
                    iataTokens.append((up, i, c))
                } else if c.range(of: #"^\d{1,2}:\d{2}$"#, options: .regularExpression) != nil || c.range(of: #"^\d{3,4}$"#, options: .regularExpression) != nil {
                    timeTokens.append((c, i))
                }
            }

            func padToken(_ tok: String?) -> String {
                guard let tok = tok, !tok.isEmpty else { return "" }
                var s = tok.replacingOccurrences(of: ":", with: "")
                s = s.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
                while s.count < 4 { s = "0" + s }
                return s
            }

            func findNearestTime(pos: Int, prefer: String = "any") -> String {
                if timeTokens.isEmpty { return "" }
                if prefer == "right" {
                    if let best = timeTokens.filter({ $0.index >= pos }).sorted(by: { $0.index < $1.index }).first { return padToken(best.t) }
                } else if prefer == "left" {
                    if let best = timeTokens.filter({ $0.index <= pos }).sorted(by: { $0.index > $1.index }).first { return padToken(best.t) }
                }
                var best: (t: String, index: Int)? = nil
                var minD = Int.max
                for t in timeTokens {
                    let d = abs(t.index - pos)
                    if d < minD { minD = d; best = t }
                }
                return padToken(best?.t)
            }

            func guessNameNear(idx: Int) -> String {
                if idx + 1 < cols.count {
                    let s = cols[idx + 1]
                    if s.uppercased().range(of: "^[A-Z]{3}$", options: .regularExpression) == nil &&
                        s.range(of: #"^\d{1,4}(:\d{2})?$"#, options: .regularExpression) == nil {
                        return s
                    }
                }
                if idx - 1 >= 0 {
                    let s = cols[idx - 1]
                    if s.uppercased().range(of: "^[A-Z]{3}$", options: .regularExpression) == nil &&
                        s.range(of: #"^\d{1,4}(:\d{2})?$"#, options: .regularExpression) == nil {
                        return s
                    }
                }
                return ""
            }

            var legs: [Leg] = []
            if iataTokens.count >= 2 {
                let limit = min(SearchEngine.MAX_SEGMENTS, iataTokens.count - 1)
                for k in 0..<limit {
                    let depTok = iataTokens[k], arrTok = iataTokens[k + 1]
                    let depTime = findNearestTime(pos: depTok.index, prefer: "right")
                    let arrTime = findNearestTime(pos: arrTok.index, prefer: "left")
                    let leg = Leg(flightNo: obj["航班号"] ?? "",
                                  dep: depTok.code,
                                  depName: guessNameNear(idx: depTok.index).isEmpty ? (k == 0 ? obj["出发机场名称_raw"] ?? "" : "") : guessNameNear(idx: depTok.index),
                                  depTime: depTime.isEmpty ? padToken(obj["出发时间_raw"]) : depTime,
                                  arr: arrTok.code,
                                  arrName: guessNameNear(idx: arrTok.index).isEmpty ? (k == iataTokens.count - 2 ? obj["到达机场名称_raw"] ?? "" : "") : guessNameNear(idx: arrTok.index),
                                  arrTime: arrTime.isEmpty ? padToken(obj["到达时间_raw"]) : arrTime)
                    legs.append(leg)
                }
            } else {
                let dep = obj["出发机场_raw"] ?? ""
                let arr = obj["到达机场_raw"] ?? ""
                let depTime = padToken(obj["出发时间_raw"])
                let arrTime = padToken(obj["到达时间_raw"])
                if !dep.isEmpty || !arr.isEmpty {
                    let leg = Leg(flightNo: obj["航班号"] ?? "", dep: dep, depName: obj["出发机场名称_raw"] ?? "", depTime: depTime, arr: arr, arrName: obj["到达机场名称_raw"] ?? "", arrTime: arrTime)
                    legs.append(leg)
                }
            }
            flights.append((obj, legs.filter { !$0.dep.isEmpty && !$0.arr.isEmpty }))
        }
        return flights
    }
}