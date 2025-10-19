import Foundation

class SearchEngine: ObservableObject {
    static let shared = SearchEngine()
    static let MAX_SEGMENTS = 5
    static let MIN_CONNECTION = 30
    static let MAX_CONNECTION_MINUTES = 48 * 60

    @Published var flightsRaw: [([String: String], [Leg])] = []
    @Published var legsAll: [Leg] = []
    @Published var legIndexByDep: [String: [Leg]] = [:]
    @Published var airportMap: [String: String] = [:]
    @Published var airportNameToIatas: [String: [String]] = [:]

    @Published var fromInput: String = ""
    @Published var toInput: String = ""
    @Published var weekday: String = ""
    @Published var results: [CandidateItinerary] = []
    @Published var message: String = "请加载 CSV 或 输入查询条件"
    @Published var savedItineraries: [ItineraryItem] = []
    @Published var history: [HistoryItem] = []

    private var cancellables = Set<AnyCancellable>()

    private init() {
        $fromInput.sink { _ in }.store(in: &cancellables)
        $toInput.sink { _ in }.store(in: &cancellables)
        loadSavedData()
    }

    func bootstrap() {
        if let url = Bundle.main.url(forResource: "华夏航空.iata.named.padded_merged", withExtension: "csv"),
           let s = try? String(contentsOf: url) {
            loadCsv(from: s)
        } else {
        }
    }

    func loadCsv(from text: String) {
        flightsRaw = CSVParser.parse(text: text)
        buildIndices()
        message = "已加载 CSV，航班记录：\(flightsRaw.count)"
    }

    private func buildIndices() {
        legIndexByDep = [:]
        airportMap = [:]
        airportNameToIatas = [:]
        legsAll = flightsRaw.flatMap { $0.1 }
        for leg in legsAll {
            let key = leg.dep.uppercased()
            legIndexByDep[key, default: []].append(leg)
            if airportMap[leg.dep] == nil { airportMap[leg.dep] = leg.depName.isEmpty ? leg.dep : leg.depName }
            if airportMap[leg.arr] == nil { airportMap[leg.arr] = leg.arrName.isEmpty ? leg.arr : leg.arrName }

            let depName = (leg.depName.isEmpty ? leg.dep : leg.depName).trimmingCharacters(in: .whitespaces)
            airportNameToIatas[depName, default: []].append(leg.dep)

            let arrName = (leg.arrName.isEmpty ? leg.arr : leg.arrName).trimmingCharacters(in: .whitespaces)
            airportNameToIatas[arrName, default: []].append(leg.arr)
        }
        for key in airportNameToIatas.keys {
            airportNameToIatas[key] = Array(Set(airportNameToIatas[key]!))
        }
    }

    var suggestedFrom: [String] {
        let q = fromInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        var results: [String] = []
        for (iata, name) in airportMap {
            if iata.lowercased().hasPrefix(q) || name.lowercased().contains(q) { results.append("\(name) (\(iata))") }
        }
        for (name, iatas) in airportNameToIatas {
            if name.lowercased().contains(q) {
                for i in iatas {
                    let s = "\(airportMap[i] ?? i) (\(i))"
                    if !results.contains(s) { results.append(s) }
                }
            }
        }
        return Array(results.prefix(60))
    }

    var suggestedTo: [String] {
        let q = toInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        var results: [String] = []
        for (iata, name) in airportMap {
            if iata.lowercased().hasPrefix(q) || name.lowercased().contains(q) { results.append("\(name) (\(iata))") }
        }
        for (name, iatas) in airportNameToIatas {
            if name.lowercased().contains(q) {
                for i in iatas {
                    let s = "\(airportMap[i] ?? i) (\(i))"
                    if !results.contains(s) { results.append(s) }
                }
            }
        }
        return Array(results.prefix(60))
    }

    func resolveInputToIata(_ display: String) -> String {
        let v = display.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.count == 3 && v.range(of: "^[A-Za-z]{3}$", options: .regularExpression) != nil {
            return v.uppercased()
        }
        if let start = v.lastIndex(of: "("), let end = v.lastIndex(of: ")"), end > start {
            let sub = v[v.index(after: start)..<end]
            if sub.range(of: "^[A-Za-z]{3}$", options: .regularExpression) != nil {
                return sub.uppercased()
            }
        }
        let low = v.lowercased()
        for (iata, name) in airportMap {
            if name.lowercased() == low { return iata }
            if name.lowercased().contains(low) || iata.lowercased().contains(low) { return iata }
        }
        return ""
    }

    func searchFlights() {
        results = []
        let originIata = resolveInputToIata(fromInput)
        let destIata = resolveInputToIata(toInput)
        if originIata.isEmpty || destIata.isEmpty {
            message = "请填写并选择出发与到达机场（可输入中文并选择）"
            return
        }
        var resultsTmp: [CandidateItinerary] = []
        func dfs(currentAirport: String, pathLegs: [Leg], visitedAirports: Set<String>) {
            var path = pathLegs
            if !path.isEmpty {
                if path.last!.arr.uppercased() == destIata {
                    let normRes = normalizeLegTimes(legs: path)
                    if normRes.ok {
                        let uniqueNos = Set(path.map { $0.flightNo })
                        let price = min(10, uniqueNos.count) * 70
                        resultsTmp.append(CandidateItinerary(legs: path, totalMinutes: normRes.totalMinutes, price: price))
                    }
                }
            }
            if path.count >= SearchEngine.MAX_SEGMENTS { return }
            let nextLegs = legIndexByDep[currentAirport] ?? []
            for leg in nextLegs {
                if visitedAirports.contains(leg.arr) { continue }
                var tentative = path
                tentative.append(leg)
                let norm = normalizeLegTimes(legs: tentative)
                if !norm.ok { continue }
                var visited = visitedAirports
                visited.insert(leg.arr)
                dfs(currentAirport: leg.arr, pathLegs: tentative, visitedAirports: visited)
            }
        }

        dfs(currentAirport: originIata, pathLegs: [], visitedAirports: Set([originIata]))
        var uniq: Set<String> = []
        var filtered: [CandidateItinerary] = []
        for r in resultsTmp {
            let key = r.legs.map { "\($0.dep)|\($0.depTime)|\($0.arr)|\($0.arrTime)|\($0.flightNo)" }.joined(separator: "->")
            if !uniq.contains(key) { uniq.insert(key); filtered.append(r) }
        }
        if filtered.isEmpty {
            message = "未找到匹配航班"
            return
        }
        let minPrice = filtered.map { $0.price }.min() ?? 0
        var lowest = filtered.filter { $0.price == minPrice }
        lowest.sort { ($0.totalMinutes ?? Int.max) < ($1.totalMinutes ?? Int.max) }
        results = lowest
        message = "找到 \(results.count) 个方案（显示最低价方案）"
    }

    func normalizeLegTimes(legs: [Leg]) -> (ok: Bool, legsAbs: [NormalizedLeg], totalMinutes: Int?) {
        if legs.isEmpty { return (false, [], nil) }
        var entries: [NormalizedLeg] = []
        var prevArrAbs: Int? = nil
        for (i, leg) in legs.enumerated() {
            guard let depM = Utils.parseHM(leg.depTime), let arrM = Utils.parseHM(leg.arrTime) else {
                return (false, [], nil)
            }
            var segDur = (arrM - depM + 1440) % 1440
            if segDur == 0 && depM == arrM { segDur = 24*60 }
            if i == 0 {
                let depAbs = depM
                let arrAbs = depAbs + segDur
                let nl = NormalizedLeg(depM: depM, arrM: arrM, depAbs: depAbs, arrAbs: arrAbs, depDayOffset: depAbs / 1440, arrDayOffset: arrAbs / 1440)
                entries.append(nl)
                prevArrAbs = arrAbs
            } else {
                guard let prev = prevArrAbs else { return (false, [], nil) }
                var k = max(0, (prev - depM) / 1440)
                var candidate = depM + k * 1440
                while candidate < prev + SearchEngine.MIN_CONNECTION {
                    k += 1
                    candidate = depM + k * 1440
                    if candidate - prev > SearchEngine.MAX_CONNECTION_MINUTES { return (false, [], nil) }
                }
                let depAbs = candidate
                let arrAbs = depAbs + segDur
                if segDur > 7 * 24 * 60 { return (false, [], nil) }
                let nl = NormalizedLeg(depM: depM, arrM: arrM, depAbs: depAbs, arrAbs: arrAbs, depDayOffset: depAbs / 1440, arrDayOffset: arrAbs / 1440)
                entries.append(nl)
                prevArrAbs = arrAbs
            }
        }
        let total = (entries.last!.arrAbs - entries.first!.depAbs)
        return (true, entries, total)
    }

    func saveItinerary(candidate: CandidateItinerary) {
        var list = StorageManager.shared.loadItineraries()
        let norm = normalizeLegTimes(legs: candidate.legs)
        let it = ItineraryItem(id: "itn_\(Int(Date().timeIntervalSince1970))",
                               createdAt: Date().timeIntervalSince1970,
                               legs: candidate.legs,
                               price: candidate.price,
                               totalMinutes: candidate.totalMinutes,
                               norm: norm.ok ? NormalizedResult(legsAbs: norm.legsAbs, totalMinutes: norm.totalMinutes ?? 0) : nil)
        list.append(it)
        StorageManager.shared.saveItineraries(list)
        loadSavedData()
    }

    func loadSavedData() {
        savedItineraries = StorageManager.shared.loadItineraries()
        history = StorageManager.shared.loadHistory()
    }
}