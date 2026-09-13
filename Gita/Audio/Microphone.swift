import AVFoundation
import Combine
import SwiftUI

enum MicrophoneState: Equatable {
    case idle
    case requestingPermission
    case listening
    case denied
    case interrupted
    case failed(String)
}

@MainActor
final class Microphone: ObservableObject {
    @Published private(set) var state: MicrophoneState = .idle
    @Published private(set) var latestSamples: [Float] = []
    @Published private(set) var sampleRate: Double = 44_100

    private var engine: AVAudioEngine?
    private var interruptionObserver: NSObjectProtocol?

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
                self?.state = .interrupted
            }
        }
    }

    func start() async {
        guard state != .listening else { return }
        state = .requestingPermission
        let permitted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard permitted else {
            state = .denied
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setPreferredSampleRate(44_100)
            try session.setActive(true)

            let newEngine = AVAudioEngine()
            let input = newEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.commonFormat == .pcmFormatFloat32 else {
                state = .failed("This microphone format is not supported.")
                try? session.setActive(false)
                return
            }
            sampleRate = format.sampleRate
            input.installTap(onBus: 0, bufferSize: 8_192, format: format) { [weak self] buffer, _ in
                guard let channel = buffer.floatChannelData?[0] else { return }
                let values = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                Task { @MainActor [weak self] in
                    self?.latestSamples = values
                }
            }
            engine = newEngine
            newEngine.prepare()
            try newEngine.start()
            state = .listening
        } catch {
            stop()
            state = .failed("Microphone could not start. Try again.")
        }
    }

    func stop() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        latestSamples = []
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }
}
