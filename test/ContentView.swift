import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var loc = Location()
    @State private var uv: UVData?
    @State private var userInputString: String = ""
    @State private var userInput2String: String = ""
    @State private var uvRecommendation: String = ""

    var body: some View {
        GeometryReader { geo in
            ZStack{
                Image("wallpaper")
                    .resizable()
                    .edgesIgnoringSafeArea(.all)
            }
            VStack {
                TextField("Enter the latitude of your location", text: $userInputString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .offset(y: 160)
                Text("You entered: \(userInputString)")
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .offset(y: 150)
                TextField("Enter the longitude of your location", text: $userInput2String)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .offset(y: 140)
                Text("You entered: \(userInput2String)")
                    .offset(y: 130)
                Button("Assign values") {
                    if let latitude = Double(userInputString), let longitude = Double(userInput2String) {
                        loc.getCurrentWeather(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude)) { result in
                            switch result {
                            case .success(let response):
                                uv = response
                                checkUVIndex(Int(uv?.uv ?? 0))
                            case .failure(let error):
                                print("Error: \(error)")
                            }
                        }
                    }
                }
                .offset(y: 135)

                if let uv = uv {
                    Text("UV Index: \(uv.uv)")
                        .offset(y: 140)
                    Text("Max UV Index: \(uv.uv_max)")
                        .offset(y: 140)
                    Text(uvRecommendation)
                        .offset(y: 140)
                } else {
                    Text("Loading...")
                        .offset(y: 140)
                }
            }
        }

        }
    func checkUVIndex(_ uvIndex: Int) {
        if uvIndex <= 0 {
            uvRecommendation = "UV is low: Sunscreen is not necessary"
        } else if uvIndex >= 3 && uvIndex <= 5 {
            uvRecommendation = "UV is moderate: SPF 15+ Sunscreen necessary"
        } else if uvIndex >= 6 && uvIndex <= 7 {
            uvRecommendation = "UV is high: SPF 30+ Sunscreen necessary"
        } else if uvIndex >= 8 && uvIndex <= 10 {
            uvRecommendation = "UV is very high: SPF 30+ Sunscreen necessary (Apply generously)"
        } else {
            uvRecommendation = "UV is extreme: SPF 50+ Sunscreen necessary (LIMIT DIRECT SUN-SKIN CONTACT <10 MINUTES)"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
