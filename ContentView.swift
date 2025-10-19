import SwiftUI

struct ContentView: View {
    @StateObject private var engine = SearchEngine.shared
    @State private var csvText: String = ""
    @State private var showingCsvEditor = false

    var body: some View {
        TabView {
            // Search Tab
            NavigationView {
                VStack(spacing: 8) {
                    Form {
                        Section(header: Text("查询条件")) {
                            AutocompleteField(title: "出发", text: $engine.fromInput, suggestions: engine.suggestedFrom)
                            AutocompleteField(title: "到达", text: $engine.toInput, suggestions: engine.suggestedTo)
                            Picker("星期（可选）", selection: $engine.weekday) {
                                Text("任意").tag("")
                                Text("周一").tag("1")
                                Text("周二").tag("2")
                                Text("周三").tag("3")
                                Text("周四").tag("4")
                                Text("周五").tag("5")
                                Text("周六").tag("6")
                                Text("周日").tag("7")
                            }.pickerStyle(MenuPickerStyle())
                            HStack {
                                Button("搜索") { engine.searchFlights() }
                                    .buttonStyle(.borderedProminent)
                                Button("粘贴 CSV / 加载") { showingCsvEditor.toggle() }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }

                    // Results
                    if engine.results.isEmpty {
                        Spacer()
                        Text(engine.message).foregroundColor(.secondary)
                        Spacer()
                    } else {
                        List {
                            ForEach(engine.results) { candidate in
                                ResultCard(candidate: candidate) {
                                    engine.saveItinerary(candidate: candidate)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("查询")
                .sheet(isPresented: $showingCsvEditor) {
                    CsvEditorView(csvText: $csvText, onLoad: {
                        engine.loadCsv(from: csvText)
                        showingCsvEditor = false
                    })
                }
            }
            .tabItem {
                Label("查询", systemImage: "airplane.up.forward.app.fill")
            }

            // Itineraries tab (current)
            NavigationView {
                ItinerariesView()
                    .navigationTitle("当前行程")
            }
            .tabItem {
                Label("行程", systemImage: "suitcase.fill")
            }

            // History tab
            NavigationView {
                HistoryView()
                    .navigationTitle("历史行程")
            }
            .tabItem {
                Label("历史", systemImage: "clock.fill")
            }
        }
        .onAppear {
            engine.bootstrap() // try auto load csv in bundle or from stored raw text
        }
    }
}

struct CsvEditorView: View {
    @Binding var csvText: String
    var onLoad: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $csvText)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    .frame(minHeight: 220)
                Spacer()
            }
            .padding()
            .navigationTitle("粘贴 CSV")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("加载") { onLoad() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: true) }
                }
            }
        }
    }
}

struct ResultCard: View {
    let candidate: CandidateItinerary
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // SF Symbol icon
                if UIImage(systemName: "airplane.up.forward.app.fill") != nil {
                    Image(systemName: "airplane.up.forward.app.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 36, height: 36)
                }

                Text("\(candidate.legs.first?.dep ?? "") → \(candidate.legs.last?.arr ?? "")")
                    .font(.headline)
                Spacer()
                Text("¥\(candidate.price)")
                    .font(.subheadline)
            }
            Text("段数 \(candidate.legs.count) • 总时长 \(formatDuration(candidate.totalMinutes))")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(candidate.legs.enumerated()), id: \.offset) { idx, leg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(leg.dep) → \(leg.arr)").font(.subheadline).bold()
                                Spacer()
                            }
                            HStack {
                                Text(formatHM(leg.depTime)).font(.caption).foregroundColor(.secondary)
                                Text("→").font(.caption)
                                Text(formatHM(leg.arrTime)).font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("航班 \(leg.flightNo)").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(action: onSave) {
                    Text("兑换")
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
        .padding(.vertical, 6)
    }

    private func formatHM(_ hm: String) -> String {
        if hm.count == 4 {
            return String(hm.prefix(2)) + ":" + String(hm.suffix(2))
        }
        return hm
    }
}

struct AutocompleteField: View {
    let title: String
    @Binding var text: String
    var suggestions: [String]

    @State private var showList = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            TextField("", text: $text, onEditingChanged: { editing in
                withAnimation { showList = editing && !suggestions.isEmpty }
            })
            .textFieldStyle(.roundedBorder)
            if showList && !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions.prefix(20), id: \.self) { s in
                            Button(action: {
                                text = s
                                withAnimation { showList = false }
                            }, label: {
                                HStack { Text(s); Spacer() }
                                    .padding(8)
                            }).buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 180)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 6)
            }
        }
    }
}