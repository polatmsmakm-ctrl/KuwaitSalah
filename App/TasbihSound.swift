import AVFoundation
import UIKit

/// أصوات المسبحة: نقرة خفيفة عند كل تسبيحة، ونغمة جميلة عند إكمال الهدف. تُولَّد في الذاكرة.
@MainActor
final class TasbihSound {
    static let shared = TasbihSound()
    private var click: [AVAudioPlayer] = []
    private var chime: AVAudioPlayer?
    private var idx = 0
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UINotificationFeedbackGenerator()

    private static func wav(_ samples: [Int16], rate: Int) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        let size = UInt32(samples.count * 2)
        d.append("RIFF".data(using: .ascii)!); u32(36 + size)
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(size)
        samples.withUnsafeBufferPointer { d.append(Data(buffer: $0)) }
        return d
    }

    /// نقرة خشبية قصيرة (حبة مسبحة)
    private static func clickData() -> Data {
        let rate = 22050
        let n = rate * 70 / 1000
        var s: [Int16] = []
        for i in 0..<n {
            let t = Double(i) / Double(rate)
            let env = exp(-t * 70)
            let v = sin(2 * .pi * 900 * t) * 0.6 + sin(2 * .pi * 1800 * t) * 0.3 + sin(2 * .pi * 420 * t) * 0.4
            s.append(Int16(max(-1, min(1, v * env * 0.8)) * 32000))
        }
        return wav(s, rate: rate)
    }

    /// نغمة إكمال: نوتتان صاعدتان
    private static func chimeData() -> Data {
        let rate = 22050
        var s: [Int16] = []
        for (f, ms) in [(659.0, 200), (880.0, 200), (1318.0, 600)] as [(Double, Int)] {
            let n = rate * ms / 1000
            for i in 0..<n {
                let t = Double(i) / Double(rate)
                let env = min(1, t * 200) * exp(-t * 4.5)
                let v = sin(2 * .pi * f * t) + 0.3 * sin(2 * .pi * f * 2 * t)
                s.append(Int16(max(-1, min(1, v * env * 0.5)) * 32000))
            }
        }
        return wav(s, rate: rate)
    }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        let c = Self.clickData()
        click = (0..<4).compactMap { _ in try? AVAudioPlayer(data: c) }
        click.forEach { $0.prepareToPlay() }
        chime = try? AVAudioPlayer(data: Self.chimeData())
        chime?.prepareToPlay()
    }

    func tap(sound: Bool) {
        light.impactOccurred(intensity: 0.8)
        guard sound, !click.isEmpty else { return }
        let p = click[idx % click.count]
        idx += 1
        p.currentTime = 0
        p.play()
    }

    func complete(sound: Bool) {
        heavy.notificationOccurred(.success)
        guard sound else { return }
        chime?.currentTime = 0
        chime?.play()
    }
}
