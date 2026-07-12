import SwiftUI

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("screenAlwaysOn") private var screenAlwaysOn = false
    @AppStorage("pageTurnerEnabled") private var pageTurnerEnabled = false
    @StateObject private var pageTurner = BLEPageTurnerManager.shared

    var body: some View {
        Form {
            Section("Display") {
                Toggle(isOn: $darkMode) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }

                Text("Switch between dark and light appearance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)

                Toggle(isOn: $screenAlwaysOn) {
                    Label("Keep Screen On", systemImage: "sun.max.fill")
                }
                .onChange(of: screenAlwaysOn) { newValue in
                    UIApplication.shared.isIdleTimerDisabled = newValue
                }
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = screenAlwaysOn
                }

                Text("Prevents the screen from dimming while viewing songs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 32)
            }

            Section("Bluetooth Page Turner") {
                Toggle(isOn: $pageTurnerEnabled) {
                    Label("Enabled", systemImage: "figure.walk")
                }
                .onChange(of: pageTurnerEnabled) { enabled in
                    if enabled {
                        BLEPageTurnerManager.shared.startScanning()
                    } else {
                        BLEPageTurnerManager.shared.disconnect()
                        BLEPageTurnerManager.shared.stopScanning()
                    }
                }

                if pageTurnerEnabled {
                    if pageTurner.isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Scanning for pedal...")
                                .foregroundStyle(.secondary)
                        }
                    } else if pageTurner.isConnected, let name = pageTurner.deviceName {
                        Label("Connected: \(name)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        if let battery = pageTurner.batteryLevel {
                            Label("Battery: \(battery)%", systemImage: "battery.100")
                                .foregroundStyle(.secondary)
                        }
                    } else if !pageTurner.isScanning {
                        Button("Scan for Pedal") {
                            BLEPageTurnerManager.shared.startScanning()
                        }
                    }
                }

                if pageTurnerEnabled {
                    Text("Pairs with AirTurn, PageFlip, and BLE MIDI page turners.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
            .onAppear {
                if pageTurnerEnabled && !pageTurner.isConnected && !pageTurner.isScanning {
                    BLEPageTurnerManager.shared.startScanning()
                }
            }

            Section("Sync") {
                NavigationLink {
                    SyncSettingsView()
                } label: {
                    Label("Codeberg Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://codeberg.org/doobidoo/FreeSong")!) {
                    HStack {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
