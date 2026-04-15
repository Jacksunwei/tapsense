import Foundation

enum TapSenseSensitivity: String, CaseIterable {
    case low
    case medium
    case high

    var title: String { rawValue.capitalized }
}

struct SidecarEvent: Decodable {
    let type: String
    let pattern: String?
    let count: Int?
    let timestamp: Double?
    let message: String?
    let mode: String?
    let profile: String?
    let sensitivity: String?
}
