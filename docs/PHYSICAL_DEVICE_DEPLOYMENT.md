# Physical Device Deployment

## Requirements

1. **Apple Developer Program** ($99/year) — https://developer.apple.com/programs
2. **Team ID** — visible at https://developer.apple.com/account after enrollment

## Setup

### 1. Set your Team ID

Edit `project.yml` and replace the empty `DEVELOPMENT_TEAM` with your 10-character Team ID:

```yaml
DEVELOPMENT_TEAM: "ABC123XYZ4"
```

### 2. Regenerate Xcode project

```bash
xcodegen generate
```

### 3. Open in Xcode

```bash
open FreeSong.xcodeproj
```

### 4. Select your device

- Plug in your iOS device via USB
- Select the device from the scheme toolbar (next to the run button)
- Xcode will handle signing certificate creation automatically

### 5. ⌘+R

Builds and installs on the connected device.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `CoreDeviceError Code 3002` | Set DEVELOPMENT_TEAM in project.yml |
| `Failed to register bundle identifier` | Change PRODUCT_BUNDLE_IDENTIFIER to something unique |
| `No signing certificate found` | Xcode should auto-create one; or go to Xcode → Settings → Accounts → Download Manual Profiles |

## Notes

- Free (no-cost) Apple accounts can sideload with a 7-day certificate expiry
- Paid Apple Developer ($99/yr) certificates last 1 year
- Push notifications, CloudKit, and iCloud require the paid account
