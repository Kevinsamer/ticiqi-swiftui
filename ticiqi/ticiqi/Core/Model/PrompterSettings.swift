//  Prompter settings — persistent configuration for teleprompter defaults
//  ticiqi
//

import SwiftUI

// MARK: - Color hex conversion

extension Color {
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "#FFFFFF" }
        let r: Int, g: Int, b: Int
        if components.count >= 3 {
            r = Int(round(components[0] * 255))
            g = Int(round(components[1] * 255))
            b = Int(round(components[2] * 255))
        } else {
            let v = Int(round(components[0] * 255))
            return String(format: "#%02X%02X%02X", v, v, v)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(hex: String) {
        let hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard hex.count == 6, let val = UInt64(hex, radix: 16) else {
            self = .white; return
        }
        self = Color(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }
}

// MARK: - Background option

enum BackgroundOption: String, CaseIterable, Codable {
    case black, darkGray

    var color: Color {
        switch self {
        case .black: return .black
        case .darkGray: return Color(white: 0.12)
        }
    }
}

// MARK: - Settings

struct PrompterSettings: Codable, Equatable {
    var defaultSpeed: CGFloat = 30.0
    var fontSize: CGFloat = 48.0
    var scrollDirection: ScrollDirection = .up
    var textColorHex: String = "#FFFFFF"
    var backgroundColor: BackgroundOption = .black
    var mirrorEnabled: Bool = false
    var focusLineEnabled: Bool = true
    var autoStartServer: Bool = true

    var textColor: Color {
        get { Color(hex: textColorHex) }
        set { textColorHex = newValue.hexString }
    }

    // MARK: - Persistence

    private static let storageKey = "prompter_settings"

    static func load() -> PrompterSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(PrompterSettings.self, from: data)
        else {
            return PrompterSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
