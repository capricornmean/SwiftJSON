import Foundation
import SwiftJSON

let path = CommandLine.arguments.dropFirst().first ?? "sample.json"
let json = try String(contentsOfFile: path, encoding: .utf8)
let data = Data(json.utf8)
print("Loaded \(json.count) chars (\(data.count) bytes) from \(path)\n")

func bench(_ name: String, iterations: Int = 20, _ block: () throws -> Void) rethrows {
    // warmup
    try block(); try block()

    let clock = ContinuousClock()
    var times: [Duration] = []
    for _ in 0..<iterations {
        times.append(try clock.measure(block))
    }
    let sorted = times.sorted()
    let minTime = sorted.first!
    let median = sorted[sorted.count / 2]
    print("\(name.padding(toLength: 22, withPad: " ", startingAt: 0)) min=\(minTime)  median=\(median)")
}

try bench("SwiftJSON") {
    for _ in 0..<5000 {
        var parser = JSONParser(json)
        _ = try parser.parse()
    }
}

try bench("JSONSerialization") {
    _ = try JSONSerialization.jsonObject(with: data)
}