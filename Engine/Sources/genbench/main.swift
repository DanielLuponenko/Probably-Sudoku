import Foundation
import ProbablySudokuEngine

for difficulty in Difficulty.allCases {
    var rng = RandomStream(seed: "bench", stream: "board")
    var times: [Double] = []
    for _ in 0..<10 {
        let t0 = DispatchTime.now().uptimeNanoseconds
        _ = try! Generator.generate(&rng, difficulty: difficulty)
        times.append(Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6)
    }
    let sorted = times.sorted()
    print(String(format: "%-7s n=10  median %6.1f ms   max %6.1f ms",
                 (difficulty.rawValue as NSString).utf8String!, sorted[5], sorted.last!))
}
