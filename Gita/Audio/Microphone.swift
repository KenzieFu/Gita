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
    private var generation = 0
    private var echoCancellationEnabled = false

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

    func start(echoCancellation: Bool = false) async {
        if state == .listening, echoCancellationEnabled == echoCancellation { return }
        if state == .listening { stop() }
        generation += 1
        let startGeneration = generation
        state = .requestingPermission
        let permitted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard generation == startGeneration else { return }
        guard permitted else {
            state = .denied
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: echoCancellation ? .voiceChat : .measurement,
                options: [.defaultToSpeaker]
            )
            try session.setPreferredSampleRate(44_100)
            try session.setActive(true)

            let newEngine = AVAudioEngine()
            let input = newEngine.inputNode
            if echoCancellation {
                try input.setVoiceProcessingEnabled(true)
                input.isVoiceProcessingBypassed = false
            }
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
                    guard self?.generation == startGeneration else { return }
                    self?.latestSamples = values
                }
            }
            engine = newEngine
            echoCancellationEnabled = echoCancellation
            newEngine.prepare()
            try newEngine.start()
            state = .listening
        } catch {
            stop()
            state = .failed("Microphone could not start. Try again.")
        }
    }

    func stop() {
        generation += 1
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        echoCancellationEnabled = false
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
