import SwiftUI

struct AyahNote: Codable, Identifiable, Hashable {
    var s: Int
    var a: Int
    var color: Int      // 0 = بلا لون، 1..4 ألوان
    var text: String
    var date: Date
    var id: String { "\(s):\(a)" }

    init(s: Int, a: Int, color: Int = 0, text: String = "", date: Date = Date()) {
        self.s = s; self.a = a; self.color = color; self.text = text; self.date = date
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        s = try c.decode(Int.self, forKey: .s)
        a = try c.decode(Int.self, forKey: .a)
        color = try c.decodeIfPresent(Int.self, forKey: .color) ?? 0
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }
}

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [String: AyahNote] = [:]
    private let key = "notes.v1"

    static let palette: [Color] = [
        .clear,
        Color(red: 0.96, green: 0.80, blue: 0.46),
        Color(red: 0.40, green: 0.80, blue: 0.55),
        Color(red: 0.45, green: 0.68, blue: 0.95),
        Color(red: 0.95, green: 0.55, blue: 0.65)
    ]

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([AyahNote].self, from: d) {
            notes = Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
        }
    }

    func note(_ ref: AyahRef) -> AyahNote? { notes[ref.id] }

    func color(_ ref: AyahRef) -> Color? {
        guard let n = notes[ref.id], n.color > 0, n.color < Self.palette.count else { return nil }
        return Self.palette[n.color]
    }

    func set(_ ref: AyahRef, color: Int, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if color == 0 && t.isEmpty {
            notes.removeValue(forKey: ref.id)
        } else {
            notes[ref.id] = AyahNote(s: ref.s, a: ref.a, color: color, text: t)
        }
        save()
    }

    var all: [AyahNote] { notes.values.sorted { $0.date > $1.date } }

    private func save() {
        if let d = try? JSONEncoder().encode(Array(notes.values)) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }
}

struct NoteSheet: View {
    let ref: AyahRef
    @EnvironmentObject var notes: NotesStore
    @EnvironmentObject var quran: QuranStore
    @Environment(\.dismiss) private var dismiss
    @State private var color = 0
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("اللون") {
                    HStack(spacing: 14) {
                        ForEach(0..<NotesStore.palette.count, id: \.self) { i in
                            Button { color = i } label: {
                                ZStack {
                                    Circle()
                                        .fill(i == 0 ? Color.gray.opacity(0.2) : NotesStore.palette[i])
                                        .frame(width: 34, height: 34)
                                    if i == 0 { Image(systemName: "slash.circle").foregroundStyle(.secondary) }
                                    if color == i { Circle().stroke(Theme.accent, lineWidth: 3).frame(width: 42, height: 42) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("ملاحظتي") {
                    TextEditor(text: $text).frame(minHeight: 110)
                }
                if let t = quran.ayahText(ref) {
                    Section("الآية") { Text(t).font(.callout) }
                }
            }
            .navigationTitle(quran.surah(ref.s).map { "\($0.name) · \(ref.a)" } ?? "ملاحظة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { notes.set(ref, color: color, text: text); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
            }
            .onAppear {
                if let n = notes.note(ref) { color = n.color; text = n.text }
            }
        }
    }
}

struct NotesListView: View {
    @EnvironmentObject var notes: NotesStore
    @EnvironmentObject var quran: QuranStore
    @State private var editing: AyahRef?

    var body: some View {
        List {
            if notes.all.isEmpty {
                Text("ما عندك ملاحظات بعد. من قائمة أي آية اختر «تظليل وملاحظة».")
                    .foregroundStyle(.secondary)
            }
            ForEach(notes.all) { n in
                let ref = AyahRef(s: n.s, a: n.a)
                Button { editing = ref } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if n.color > 0 { Circle().fill(NotesStore.palette[n.color]).frame(width: 12, height: 12) }
                            Text("\(quran.surah(n.s)?.name ?? "") · آية \(n.a)").font(.subheadline.bold())
                        }
                        if let t = quran.ayahText(ref) { Text(t).font(.callout).lineLimit(2) }
                        if !n.text.isEmpty { Text(n.text).font(.footnote).foregroundStyle(Theme.accent) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("ملاحظاتي")
        .sheet(item: $editing) { r in NoteSheet(ref: r) }
    }
}
