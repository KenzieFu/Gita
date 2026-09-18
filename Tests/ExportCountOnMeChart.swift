import Foundation

@main
enum ExportCountOnMeChart {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw SongChartError.invalid("Pass one exact private output JSON path")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let path = output.path
        guard output.pathExtension.lowercased() == "json",
              !path.contains("/Gita-Chart-Studio/public/"),
              !path.contains("/Gita-Chart-Studio/dist/"),
              !path.contains(".app/"),
              !path.contains("/Mobile-App/Gita/Gita/") else {
            throw SongChartError.invalid("Output must be private, outside web assets and the app bundle")
        }
        let chart = CountOnMePrototype.makeChart()
        try chart.validate()
        try JSONEncoder().encode(chart).write(to: output, options: .atomic)
        print("Wrote local timing draft to \(output.path)")
    }
}
