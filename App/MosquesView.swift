import SwiftUI

struct MosquesView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Mosque?
    @State private var query: String = ""

    private var filtered: [Mosque] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return store.allMosques }
        return store.allMosques.filter { $0.name.contains(q) || $0.area.contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { m in
                        Button {
                            store.prefs.selectedMosqueID = m.id
                        } label: {
                            row(m)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            if store.isCustom(m) {
                                Button(role: .destructive) {
                                    store.delete(m)
                                } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if store.isCustom(m) {
                                Button {
                                    editing = m
                                } label: {
                                    Label("تعديل", systemImage: "pencil")
                                }
                                .tint(.blue)
                            } else {
                                Button {
                                    editing = store.duplicate(m)
                                } label: {
                                    Label("نسخ وتعديل", systemImage: "doc.on.doc")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                } footer: {
                    Text("الإقامة بالدقائق بعد الأذان. المساجد المعلّمة «تقديرية» أوقاتها غير مؤكدة، اسحب الصف لنسخها وتعديلها.")
                }
            }
            .searchable(text: $query, prompt: "ابحث عن مسجد")
            .navigationTitle("المساجد")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        editing = Mosque.blank()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { m in
                MosqueEditor(mosque: m) { saved in
                    store.upsert(saved)
                }
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
    }

    private func row(_ m: Mosque) -> some View {
        let fmt = store.fmt
        let names = ["ف", "ظ", "ع", "م", "ش"]
        let summary = zip(names, m.iqama).map { "\($0) \(fmt.number($1))" }.joined(separator: " · ")
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m.name).font(.headline)
                    if m.estimated {
                        Text("تقديرية")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                    }
                }
                if !m.area.isEmpty {
                    Text(m.area).font(.caption).foregroundStyle(.secondary)
                }
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.prefs.selectedMosqueID == m.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

struct MosqueEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Mosque
    let onSave: (Mosque) -> Void

    init(mosque: Mosque, onSave: @escaping (Mosque) -> Void) {
        _draft = State(initialValue: mosque)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("المسجد") {
                    TextField("اسم المسجد", text: $draft.name)
                    TextField("المنطقة (اختياري)", text: $draft.area)
                }
                Section("الإقامة بعد الأذان (بالدقائق)") {
                    ForEach(Array(Prayer.fivePrayers.enumerated()), id: \.offset) { idx, p in
                        Stepper(value: $draft.iqama[idx], in: 0...60) {
                            HStack {
                                Text(p.arabicName)
                                Spacer()
                                Text("\(draft.iqama[idx]) دقيقة")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .navigationTitle("تعديل المسجد")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("حفظ") {
                        var m = draft
                        m.estimated = false
                        if m.name.trimmingCharacters(in: .whitespaces).isEmpty { m.name = "مسجد" }
                        onSave(m)
                        dismiss()
                    }
                    .bold()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("إلغاء") { dismiss() }
                }
            }
        }
    }
}
