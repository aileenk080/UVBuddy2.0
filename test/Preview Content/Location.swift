//
//  Location.swift
//  test
//
//  Created by Aileen Kim on 10/16/23.
//

import Foundation
import CoreLocation

class Location: ObservableObject {
    @Published var latitude: CLLocationDegrees?
    @Published var longitude: CLLocationDegrees?

    func getCurrentWeather(latitude: CLLocationDegrees, longitude: CLLocationDegrees, completion: @escaping (Result<UVData, Error>) -> Void) {
        guard let url = URL(string: "https://api.openuv.io/api/v1/uv?lat=\(latitude)&lng=\(longitude)") else {
            completion(.failure(NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing URL"])))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("openuv-3jqrrln6anez7-io", forHTTPHeaderField: "x-access-token")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "Location", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                let uvResponse = try JSONDecoder().decode(UVResponse.self, from: data)
                completion(.success(uvResponse.result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
struct UVResponse: Decodable {
    let result: UVData
}

struct UVData: Decodable {
    let uv: Double
    let uv_max: Double
}

