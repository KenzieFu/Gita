import Foundation

struct GuideEventSchedule {
    let noteOnsets: [Double]
    let beatOnsets: [Double]

    init(chart: SongChart, section: SongSection, rate: Double) {
        let timeline = SongPlaybackTimeline(sourceStart: section.startSeconds, rate: rate)
        noteOnsets = chart.notes
            .filter { $0.onsetSeconds >= section.startSeconds && $0.onsetSeconds < section.endSeconds }
            .map { timeline.elapsed(forSourceSeconds: $0.onsetSeconds) }

        let secondsPerBeat = 60 / chart.nominalBPM
        let firstIndex = max(0, Int(ceil((section.startSeconds - chart.firstBeatOffsetSeconds) / secondsPerBeat)))
        let lastIndex = Int(floor((section.endSeconds - chart.firstBeatOffsetSeconds) / secondsPerBeat))
        if lastIndex >= firstIndex {
            beatOnsets = (firstIndex...lastIndex).compactMap { index in
                let sourceTime = chart.firstBeatOffsetSeconds + Double(index) * secondsPerBeat
                return sourceTime < section.endSeconds ? timeline.elapsed(forSourceSeconds: sourceTime) : nil
            }
        } else {
            beatOnsets = []
        }
    }
}
