import SwiftUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    @StateObject var loc = Location()
    @State private var uv: UVData?
    @State private var skinType: FitzpatrickType = .type3
    @State private var aiExplanation: String = ""
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
                    
                    VStack(spacing: 15) {
                        
                        Picker("Skin type", selection: $skinType) {
                            ForEach(FitzpatrickType.allCases) { type in
                                Text(type.label).tag(type)
                            }
                        }
                        .pickerStyle(.menu)

                        SkinTypePhotoPicker(skinType: $skinType)
                        
                        // NEW: Clean button to trigger location fetch
                        Button("Get UV Index for My Location") {
                            loc.requestLocation()
                        }
                        .padding(.top, 10)
                        .buttonStyle(.borderedProminent) // Makes the button look like a primary action
                        
                        // If location is denied, show a warning
                        if loc.authorizationDenied {
                            Text("Location access denied. Please enable in Settings.")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        if let uv = uv {
                            Text("UV Index: \(uv.uv)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(Color.black)
                            
                            Text("Max UV Index: \(uv.uv_max)")
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Text(uvRecommendation)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color.red)
                                .multilineTextAlignment(.center)
                            
                            if !aiExplanation.isEmpty {
                                Text(aiExplanation)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        } else if loc.latitude == nil {
                            Text("Tap above to load...")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Loading UV Data...")
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(String(format: "%02d:%02d:%02d", hours, minutes, seconds))")
                            .font(.system(size: 40, weight: .bold))
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
                        
                        HStack(alignment: .bottom, spacing: 30) {
                            Button("Start") {
                                timerRunning = true
                                let rec = sunSafetyRecommendation(skinType: skinType, uvIndex: Int(uv?.uv.rounded() ?? 0))
                                scheduleReapplyNotification(uvIndex: Int(uv?.uv.rounded() ?? 0), spf: rec.spf, reapplyMinutes: rec.reapplyMinutes)
                            }
                            
                            Button("Stop") {
                                timerRunning = false
                            }
                            
                            Button("Reset") {
                                timerRunning = false
                                hours = 2
                                minutes = 0
                                seconds = 0
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.top, 120)
                }
            }
            // NEW: This listens for when Location.swift finds the user's coordinates
            .onChange(of: loc.latitude) { newLat in
                if let lat = newLat, let lon = loc.longitude {
                    loc.getCurrentWeather(latitude: lat, longitude: lon) { result in
                        switch result {
                        case .success(let response):
                            uv = response
                            checkUVIndex(Int(uv?.uv.rounded() ?? 0))
                        case .failure(let error):
                            print("Error fetching weather: \(error)")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $shouldShowOnboarding) {
                OnboardingView(shouldShowOnboarding: $shouldShowOnboarding)
            }
        }
    
    func checkUVIndex(_ uvIndex: Int) {
        let rec = sunSafetyRecommendation(skinType: skinType, uvIndex: uvIndex)
        hours = rec.reapplyMinutes / 60
        minutes = rec.reapplyMinutes % 60
        uvRecommendation = rec.summary

        fetchPersonalizedExplanation(skinType: skinType, uvIndex: uvIndex, rec: rec) { result in
            switch result {
            case .success(let message):
                aiExplanation = message
            case .failure(let error):
                print("AI explanation error: \(error)")
            }
        }
    }
    func scheduleReapplyNotification(uvIndex: Int, spf: Int, reapplyMinutes: Int) {
        let timeOfDay = Calendar.current.component(.hour, from: Date()) < 12 ? "morning" : "afternoon"

        fetchNotificationMessage(uvIndex: uvIndex, spf: spf, reapplyMinutes: reapplyMinutes, timeOfDay: timeOfDay) { message in
            let content = UNMutableNotificationContent()
            content.title = "Reapply sunscreen"
            content.body = message ?? "It's time to reapply your SPF \(spf) sunscreen."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(reapplyMinutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "reapplyReminder", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    
    struct OnboardingView: View {
            @Binding var shouldShowOnboarding: Bool
            
            var body: some View {
                TabView {
                    PageView(
                        title: "UVBuddy",
                        message: "UVBuddy helps you easily track your sunscreen usage.",
                        imageName: "sun.max.fill",
                        showsDismissButton: false,
                        shouldShowOnboarding: $shouldShowOnboarding
                    )
                    
                    PageView(
                        title: "Your UV Index",
                        message: "UVBuddy uses your location to automatically track the UV Index, suggesting a timer and SPF Level!",
                        imageName: "sun.dust.fill",
                        showsDismissButton: false,
                        shouldShowOnboarding: $shouldShowOnboarding
                    )
                    
                    PageView(
                        title: "Location",
                        message: "Please enable your location or manually enter your longitude and latitude.",
                        imageName: "location.fill",
                        showsDismissButton: false,
                        shouldShowOnboarding: $shouldShowOnboarding
                    )
                    
                    PageView(
                        title: "Notifications",
                        message: "Please enable notifications to be notified when your reapplication time is approaching.",
                        imageName: "bell.fill",
                        showsDismissButton: true,
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
                    // Changed to systemName to use Apple's built-in icons
                    Image(systemName: imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .foregroundColor(.yellow) // Added color for the system icons
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
        }
        struct ContentView_Previews: PreviewProvider {
            static var previews: some View {
                ContentView()
            }
        }
    }
