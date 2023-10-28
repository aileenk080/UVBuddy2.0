import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var loc = Location()
    @State private var uv: UVData?
    @State private var userInputString: String = ""
    @State private var userInput2String: String = ""
    @State private var uvRecommendation: String = ""
    @State private var hours: Int = 2
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var timerRunning = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @AppStorage("shouldShowOnboarding")var shouldShowOnboarding: Bool=true
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
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
                    Text("UV Index")
                        .offset(y: 140)
                        .font(
                            .system(size: 35)
                                .weight(.heavy)
                        )
                    Text("\(uv.uv)")
                        .offset(y:140)
                        .font(
                            .system(size: 25)
                                .weight(.heavy)
                        )
                    Text("Max UV Index:")
                        .offset(y: 140)
                        .font(
                            .system(size: 35)
                                .weight(.heavy)
                        )
                    Text("\(uv.uv_max)")
                        .offset(y:140)
                        .font(
                            .system(size: 25)
                                .weight(.heavy)
                        )
                    Text(uvRecommendation)
                        .offset(y: 140)
                        .font(
                            .system(size:35)
                            .weight(.heavy)
                        )
                } else {
                    Text("Loading...")
                        .offset(y: 140)
                }
                Text("\(String(format: "%02d:%02d:%02d", hours, minutes, seconds))")
                    .padding()
                    .offset(y: 130)
                    .onReceive(timer) { _ in
                        if timerRunning {
                            if seconds > 0 {
                                seconds -= 1
                            } else {
                                if minutes > 0 {
                                    minutes -= 1
                                    seconds = 59
                                } else {
                                    if hours > 0 {
                                        hours -= 1
                                        minutes = 59
                                        seconds = 59
                                    }
                                }
                            }
                        }
                    }
                    .font(.system(size: 40, weight: .bold))
                    
                HStack(alignment: .bottom, spacing: 30) {
                    Button("Start") {
                        timerRunning = true
                    } .offset(y: 130)
                    Button("Stop") {
                        timerRunning = false
                    } .offset(y: 130)
                    Button("Reset") {
                        timerRunning = false
                        hours = 2
                        minutes = 0
                        seconds = 0
                    }.foregroundColor(.red)
                        .offset(y: 130)
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


struct OnboardingView: View {
@Binding var shouldShowOnboarding: Bool

var body: some View {
    TabView {
        PageView(
            title: "UVBuddy", message: "UVBuddy helps you easily track your sunscreen usage.", imageName: "cloud.sun.rain.fill",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Your UV Index", message: "UVBuddy uses your location to automatically track the UV Index, suggesting a timer and SPF Level!", imageName: "sun.max.trianglebadge.exclamationmark",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Location", message: "Please enable your location or manually enter your longitude and latitude.", imageName: "location",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Notifications", message: "Please enable notifications to be notified when your reapplication time is approaching.", imageName: "bell", showsDismissButton: true,
                shouldShowOnboarding: $shouldShowOnboarding
            
        )
        }
    .tabViewStyle(PageTabViewStyle())
    }
}
struct PageView: View {
    let title: String
    let message: String
    let imageName: String
    let showsDismissButton: Bool
    @Binding var shouldShowOnboarding: Bool
    @State private var isPulsating = false


    var body: some View {
        VStack {
            Image (systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width:150, height:150)
                .padding ()
                .scaleEffect(isPulsating ? 1.2 : 1.0)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1).repeatForever()) {
                        self.isPulsating.toggle()
                    }
                }
            Text (title)
                .font (.system(size: 32))
                .padding()
            Text (message)
                .multilineTextAlignment(.center)
                .font (.system(size: 24))
                .foregroundColor (Color (.secondaryLabel))
                .padding ()
            
            if showsDismissButton {
                Button(action: {
                    shouldShowOnboarding.toggle()
                },label: {
                    Text ("Get Started" )
                        .bold ()
                        .foregroundColor (Color.white)
                        .frame (width: 200, height: 50)
                        .background(Color.green)
                        .cornerRadius (6)
                })
            }
        }
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
