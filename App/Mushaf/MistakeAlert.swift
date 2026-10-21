import AVFoundation
import AudioToolbox
import UIKit

/// تنبيه الخطأ في التسميع: نغمة تحذير قصيرة + اهتزاز قوي
final class MistakeAlert {
    static let shared = MistakeAlert()
    private var player: AVAudioPlayer?
    private let haptic = UINotificationFeedbackGenerator()

    /// نغمة مزدوجة منخفضة (٢٢٠ هرتز) تُولَّد في الذاكرة بدون ملفات
    private lazy var tone: Data = {
        let rate = 22050.0
        var samples: [Int16] = []
        func burst(_ ms: Double) {
            let n = Int(rate * ms / 1000)
            for i in 0..<n {
                let env = min(1, Double(i) / 200, Double(n - i) / 400)
                let v = sin(2 * .pi * 220 * Double(i) / rate) + 0.4 * sin(2 * .pi * 440 * Double(i) / rate)
                samples.append(Int16(max(-1, min(1, v * 0.6 * env)) * 32000))
            }
        }
        func silence(_ ms: Double) { samples.append(contentsOf: [Int16](repeating: 0, count: Int(rate * ms / 1000))) }
        burst(160); silence(70); burst(220)
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let dataSize = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + dataSize)
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(dataSize)
        samples.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        return d
    }()

    func fire() {
        haptic.prepare()
        haptic.notificationOccurred(.error)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        if let p = try? AVAudioPlayer(data: tone) {
            player = p
            p.volume = 1
            p.play()
        }
    }
}
