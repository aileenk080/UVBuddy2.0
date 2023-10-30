import SwiftUI
import CoreLocation
import UserNotifications

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
    @AppStorage("shouldShowOnboarding") var shouldShowOnboarding: Bool = true
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(Color.black)
                        .offset(y: 140)
                    Text("Max UV Index: \(uv.uv_max)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .offset(y: 140)
                    Text(uvRecommendation)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.red)
                        .multilineTextAlignment(.center)
                        .offset(y: 140)
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
        .fullScreenCover(isPresented: $shouldShowOnboarding) {
            OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
        }
    }

    func checkUVIndex(_ uvIndex: Int) {
        if uvIndex <= 0 && uvIndex <= 3 {
            uvRecommendation = "UV is low: Sunscreen is not necessary"
        } else if uvIndex >= 3 && uvIndex <= 5 {
            uvRecommendation = "UV is moderate: SPF 15+ Sunscreen necessary"
        } else if uvIndex >= 6 && uvIndex <= 7 {
            uvRecommendation = "UV is high: SPF 30+ Sunscreen necessary"
        } else if uvIndex >= 8 && uvIndex <= 10 {
            uvRecommendation = "UV is very high: SPF 30+ Sunscreen necessary (Apply generously)"
        } else {
            uvRecommendation = "UV is extreme: SPF 50+ Sunscreen necessary. Limit direct sun to skin contact to less than 10 Minutes."
        }
    }
}


struct OnboardingView: View {
@Binding var shouldShowOnboarding: Bool

var body: some View {
    TabView {
        PageView(
            title: "UVBuddy", message: "UVBuddy helps you easily track your sunscreen usage.", imageName: "uvbud",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Your UV Index", message: "UVBuddy uses your location to automatically track the UV Index, suggesting a timer and SPF Level!", imageName: "sunscreen",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Location", message: "Please enable your location or manually enter your longitude and latitude.", imageName: "location",showsDismissButton: false,
            shouldShowOnboarding: $shouldShowOnboarding

        )
        PageView(
            title: "Notifications", message: "Please enable notifications to be notified when your reapplication time is approaching.", imageName: "notification", showsDismissButton: true,
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
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .padding()
                .scaleEffect(isPulsating ? 1.2 : 1.0)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1).repeatForever()) {
                        self.isPulsating.toggle()
                    }
                }
            Text(title)
                .font(.system(size: 32))
                .padding()
            Text(message)
                .multilineTextAlignment(.center)
                .font(.system(size: 24))
                .foregroundColor(Color(.secondaryLabel))
                .padding()

            if showsDismissButton {
                Button(action: {
                    requestNotificationAuthorization()
                }, label: {
                    Text("Enable Notifications")
                        .bold()
                        .foregroundColor(Color.white)
                        .frame(width: 200, height: 50)
                        .background(Color.green)
                        .cornerRadius(6)
                })
            }
        }
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                // The user granted permission
                shouldShowOnboarding.toggle()
            } else if let error = error {
                // Handle error
                print("Error requesting notification authorization: \(error.localizedDescription)")
            } else {
                // The user denied permission or the permission dialog was dismissed
                print("User denied notification permission")
            }
        }
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
