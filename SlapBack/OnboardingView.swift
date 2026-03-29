import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("volume") private var volume: Double = 0.7
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: welcomePage
                case 1: menuBarPage
                default: tryItPage
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if page < 2 {
                    Button("Next") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Slapping") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 420, height: 340)
    }

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("Welcome to SlapBack")
                .font(.title.bold())
            Text("Your Mac hits back.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Slap your MacBook and it responds with sounds, screen flashes, and combo tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var menuBarPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Lives in Your Menu Bar")
                .font(.title2.bold())
            Text("SlapBack runs quietly in the menu bar. Click the hand icon to access controls, change sound packs, and adjust sensitivity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 20) {
                Label("Ctrl+Shift+S", systemImage: "keyboard")
                Text("Toggle detection")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var tryItPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Give It a Slap!")
                .font(.title2.bold())
            Text("Slap the area next to your trackpad. Harder slaps make louder sounds and trigger combos!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack {
                Image(systemName: "speaker.wave.2")
                Slider(value: $volume, in: 0...1)
                Text(String(format: "%.0f%%", volume * 100))
                    .font(.caption).monospacedDigit().frame(width: 35)
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
            .onChange(of: volume) { _, v in
                AppState.engine.applyVolume(Float(v))
            }
            Label("Turn down if in public!", systemImage: "speaker.wave.3")
                .font(.caption.bold())
                .foregroundStyle(.orange)
            Spacer()
        }
    }
}
