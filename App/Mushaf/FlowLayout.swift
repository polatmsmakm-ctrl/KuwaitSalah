import SwiftUI

/// تخطيط يلفّ العناصر على أسطر؛ يدعم الاتجاه من اليمين لليسار (الكلمة الأولى على اليمين).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 10
    var rtl = true

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, s) in subviews.enumerated() {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((index: i, size: size))
            x += size.width + spacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 320
        let rs = rows(for: subviews, maxWidth: maxW)
        var height: CGFloat = 0
        for (n, row) in rs.enumerated() {
            height += row.map { $0.size.height }.max() ?? 0
            if n < rs.count - 1 { height += lineSpacing }
        }
        return CGSize(width: proposal.width ?? maxW, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rs = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rs {
            let h = row.map { $0.size.height }.max() ?? 0
            var cx = rtl ? bounds.maxX : bounds.minX
            for item in row {
                if rtl {
                    subviews[item.index].place(at: CGPoint(x: cx - item.size.width, y: y), anchor: .topLeading,
                                               proposal: ProposedViewSize(item.size))
                    cx -= item.size.width + spacing
                } else {
                    subviews[item.index].place(at: CGPoint(x: cx, y: y), anchor: .topLeading,
                                               proposal: ProposedViewSize(item.size))
                    cx += item.size.width + spacing
                }
            }
            y += h + lineSpacing
        }
    }
}
