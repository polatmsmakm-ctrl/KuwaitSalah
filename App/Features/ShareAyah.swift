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

enum SharePresenter {
    @MainActor
    static func present(_ items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        while let p = top.presentedViewController { top = p }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
        top.present(vc, animated: true)
    }
}

struct ShareAyahImageButton: View {
    let text: String
    let caption: String

    var body: some View {
        Button {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if let ui = AyahImage.render(text: text, caption: caption) {
                    SharePresenter.present([ui])
                }
            }
        } label: {
            Label("مشاركة كصورة", systemImage: "photo")
        }
    }
}
