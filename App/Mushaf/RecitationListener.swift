import AVFoundation
import Foundation
import Speech

/// يستمع لتلاوتك عبر الميكروفون ويحوّلها إلى كلمات (التعرّف الصوتي من أبل بالعربية)
final class RecitationListener: ObservableObject {
    @Published private(set) var heard: [String] = []
    @Published private(set) var isListening = false
    @Published var error: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        error = nil
        heard = []
        guard let recognizer = recognizer, recognizer.isAvailable else {
            error = "التعرّف الصوتي بالعربية غير متاح الآن على هذا الجهاز."
            return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.error = "فعّل إذن التعرّف على الكلام للتطبيق من الإعدادات."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.error = "فعّل إذن الميكروفون للتطبيق من الإعدادات."
                            return
                        }
                        self.begin(recognizer)
                    }
                }
            }
        }
    }

    private func begin(_ recognizer: SFSpeechRecognizer) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isListening = true
            task = recognizer.recognitionTask(with: req) { [weak self] result, err in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let r = result {
                        self.heard = r.bestTranscription.formattedString
                            .split(whereSeparator: { $0 == " " || $0 == "\n" })
                            .map(String.init)
                    }
                    if err != nil || result?.isFinal == true {
                        self.finish()
                    }
                }
            }
        } catch {
            self.error = "تعذّر تشغيل الميكروفون."
            finish()
        }
    }

    func stop() {
        request?.endAudio()
        finish()
    }

    private func finish() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }
}
