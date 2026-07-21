//
//  SunSafety.swift
//  test
//
//  Created by Aileen Kim on 7/20/26.
//

import Foundation


enum FitzpatrickType: Int, CaseIterable, Identifiable {
    case type1 = 1
    case type2
    case type3
    case type4
    case type5
    case type6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .type1: return "Type I — Very fair, always burns"
        case .type2: return "Type II — Fair, usually burns"
        case .type3: return "Type III — Medium, sometimes burns"
        case .type4: return "Type IV — Olive, rarely burns"
        case .type5: return "Type V — Brown, very rarely burns"
        case .type6: return "Type VI — Deeply pigmented, never burns"
        }
    }
}


enum UVBucket: CaseIterable {
    case low        // UV 1-2
    case moderate   // UV 3-5
    case high       // UV 6-7
    case veryHigh   // UV 8-10
    case extreme    // UV 11+

    static func from(_ uvIndex: Int) -> UVBucket {
        switch uvIndex {
        case ..<3:
            return .low
        case 3...5:
            return .moderate
        case 6...7:
            return .high
        case 8...10:
            return .veryHigh
        default:
            return .extreme
        }
    }
}

// Values = maximum suggested minutes between applications of broad-spectrum SPF 30+.

let reapplyTable: [FitzpatrickType: [UVBucket: Int]] = [
    .type1: [.low: 120, .moderate: 60,  .high: 40,  .veryHigh: 20, .extreme: 10],
    .type2: [.low: 120, .moderate: 80,  .high: 60,  .veryHigh: 30, .extreme: 20],
    .type3: [.low: 180, .moderate: 100, .high: 80,  .veryHigh: 40, .extreme: 30],
    .type4: [.low: 180, .moderate: 120, .high: 100, .veryHigh: 60, .extreme: 40],
    .type5: [.low: 200, .moderate: 140, .high: 120, .veryHigh: 80, .extreme: 60],
    .type6: [.low: 200, .moderate: 160, .high: 140, .veryHigh: 100, .extreme: 80],
]

/// Minutes until reapplication is recommended, given skin type and current UV index.
func reapplyMinutes(skinType: FitzpatrickType, uvIndex: Int) -> Int {
    let bucket = UVBucket.from(uvIndex)
    // Fallback of 60 minutes should never actually trigger since the table
    // is fully populated for every FitzpatrickType x UVBucket combination.
    return reapplyTable[skinType]?[bucket] ?? 60
}

/// Recommended SPF based on UV index alone (the reapply table assumes SPF 30+ throughout,
/// this covers the lower/upper ends where a different SPF is more appropriate).
func recommendedSPF(uvIndex: Int) -> Int {
    switch uvIndex {
    case ..<3:
        return 15
    case 3...7:
        return 30
    default:
        return 50
    }
}


struct SunSafetyRecommendation {
    let spf: Int
    let reapplyMinutes: Int
    let summary: String
}

/// Single entry point ContentView can call once it has a UV index and the user's skin type.
func sunSafetyRecommendation(skinType: FitzpatrickType, uvIndex: Int) -> SunSafetyRecommendation {
    let spf = recommendedSPF(uvIndex: uvIndex)
    let mins = reapplyMinutes(skinType: skinType, uvIndex: uvIndex)
    let summary = "SPF \(spf)+ recommended. Reapply every \(mins) minutes."
    return SunSafetyRecommendation(spf: spf, reapplyMinutes: mins, summary: summary)
}


// MARK: - AI-personalized explanation

struct AIExplanationResponse: Decodable {
    let message: String
}

func fetchPersonalizedExplanation(
    skinType: FitzpatrickType,
    uvIndex: Int,
    rec: SunSafetyRecommendation,
    completion: @escaping (Result<String, Error>) -> Void
) {
    guard let url = URL(string: "https://uvbuddy-worker.uvbuddy.workers.dev/explain") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "skinType": skinType.label,
        "uvIndex": uvIndex,
        "spf": rec.spf,
        "reapplyMinutes": rec.reapplyMinutes
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: request) { data, _, error in
        if let error = error {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }
        guard let data = data else { return }
        do {
            let decoded = try JSONDecoder().decode(AIExplanationResponse.self, from: data)
            DispatchQueue.main.async { completion(.success(decoded.message)) }
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
        }
    }.resume()
}

// MARK: - AI-generated notification copy

func fetchNotificationMessage(
    uvIndex: Int,
    spf: Int,
    reapplyMinutes: Int,
    timeOfDay: String,
    completion: @escaping (String?) -> Void
) {
    guard let url = URL(string: "https://uvbuddy-worker.uvbuddy.workers.dev/notification-message") else {
        completion(nil)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: [
        "uvIndex": uvIndex, "spf": spf, "reapplyMinutes": reapplyMinutes, "timeOfDay": timeOfDay
    ])

    URLSession.shared.dataTask(with: request) { data, _, _ in
        guard let data = data,
              let decoded = try? JSONDecoder().decode(AIExplanationResponse.self, from: data) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        DispatchQueue.main.async { completion(decoded.message) }
    }.resume()
}
