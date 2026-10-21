import SwiftUI

/// بطاقة آية بخلفية سديم، تُحوَّل لصورة للمشاركة.
struct AyahCardView: View {
    let text: String
    let caption: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.16),
                                    Color(red: 0.12, green: 0.06, blue: 0.26),
                                    Color(red: 0.02, green: 0.16, blue: 0.20)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Theme.gold.opacity(0.25), .clear], center: .top, startRadius: 10, endRadius: 520)
            VStack(spacing: 36) {
                Text("﷽").font(.custom("AmiriQuran-Regular", size: 56)).foregroundStyle(Theme.gold)
                Text(text)
                    .font(.custom("AmiriQuran-Regular", size: text.count > 140 ? 40 : 56))
                    .lineSpacing(18)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.horizontal, 60)
                Text(caption).font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.gold)
                Text("منار القرآن").font(.system(size: 22)).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 80)
        }
        .frame(width: 1080, height: 1350)
    }
}

@MainActor
enum AyahImage {
    static func render(text: String, caption: String) -> UIImage? {
        let r = ImageRenderer(content: AyahCardView(text: text, caption: caption))
        r.scale = 1
        return r.uiImage
    }
}

struct ShareAyahImageButton: View {
    let text: String
    let caption: String
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(caption, image: image)) {
                    Label("مشاركة كصورة", systemImage: "photo")
                }
            } else {
                Button { } label: { Label("مشاركة كصورة", systemImage: "photo") }
                    .task {
                        if let ui = AyahImage.render(text: text, caption: caption) { image = Image(uiImage: ui) }
                    }
            }
        }
    }
}
