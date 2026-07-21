//
//  Location.swift
//  test
//
//  Created by Aileen Kim on 10/16/23.
//


import Foundation
import CoreLocation

class Location: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var latitude: CLLocationDegrees?
    @Published var longitude: CLLocationDegrees?
    @Published var authorizationDenied = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied {
            authorizationDenied = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        DispatchQueue.main.async {
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    // unchanged from before
    func getCurrentWeather(latitude: CLLocationDegrees, longitude: CLLocationDegrees, completion: @escaping (Result<UVData, Error>) -> Void) {
        guard let url = URL(string: "https://api.openuv.io/api/v1/uv?lat=\(latitude)&lng=\(longitude)") else {
            completion(.failure(NSError(domain: "Location", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing URL"])))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(loadOpenUVKey(), forHTTPHeaderField: "x-access-token")
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

func loadOpenUVKey() -> String {
    guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
          let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
          let key = plist["OpenUVAPIKey"] as? String else {
        fatalError("Missing or invalid Secrets.plist — add OpenUVAPIKey")
    }
    return key
}
