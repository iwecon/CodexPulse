import Foundation

/// Derives wallpaper-adaptive text colors.
///
/// Polarity (dark vs. light text) is chosen with APCA perceptual contrast,
/// which tracks readability on mid-luminance and saturated backgrounds better
/// than the WCAG 2 ratio. The concrete text color then continues the
/// background's hue in OKLCh at a near-black or near-white lightness, and is
/// only accepted when it keeps a WCAG contrast ratio of at least
/// `minimumContrastRatio` against every candidate background; otherwise the
/// tint interpolates toward pure black or white until the ratio holds.
enum AdaptiveTextColor {
    static let minimumContrastRatio = 7.0
    /// Lc band inside which polarity keeps the previous appearance, so panels
    /// do not flicker when black and white text are perceptually equivalent.
    static let polarityHysteresisLc = 6.0
    static let maximumChroma = 0.06
    static let chromaScale = 0.55
    /// OKLab lightness of the tinted text before any contrast correction.
    static let tintedLightLightness = 0.93
    static let tintedDarkLightness = 0.22

    struct OKLab: Sendable, Equatable {
        let lightness: Double
        let a: Double
        let b: Double

        var chroma: Double { (a * a + b * b).squareRoot() }
        var hueRadians: Double { atan2(b, a) }
    }

    // MARK: - Polarity

    /// Chooses dark or light text with maximin APCA contrast across every
    /// candidate background color, keeping the previous appearance inside the
    /// hysteresis band.
    static func appearance(
        forCandidateColors colors: [WallpaperRGB],
        previous: PanelSemanticAppearance?
    ) -> PanelSemanticAppearance? {
        guard !colors.isEmpty else { return nil }
        let backgrounds = colors.map(apcaLuminance(of:))
        let blackText = apcaLuminance(of: WallpaperRGB(red: 0, green: 0, blue: 0))
        let whiteText = apcaLuminance(of: WallpaperRGB(red: 1, green: 1, blue: 1))
        let blackMinimum = backgrounds.map {
            abs(apcaContrast(textLuminance: blackText, backgroundLuminance: $0))
        }.min() ?? 0
        let whiteMinimum = backgrounds.map {
            abs(apcaContrast(textLuminance: whiteText, backgroundLuminance: $0))
        }.min() ?? 0
        if abs(blackMinimum - whiteMinimum) <= polarityHysteresisLc, let previous {
            return previous
        }
        return blackMinimum >= whiteMinimum ? .light : .dark
    }

    // MARK: - Text color

    /// Produces the concrete text color for the chosen polarity: the
    /// background hue at near-extreme lightness, pushed toward pure black or
    /// white until every candidate background keeps `minimumContrastRatio`.
    static func textColor(
        forCandidateColors colors: [WallpaperRGB],
        appearance: PanelSemanticAppearance
    ) -> WallpaperRGB {
        let pure = appearance == .dark
            ? WallpaperRGB(red: 1, green: 1, blue: 1)
            : WallpaperRGB(red: 0, green: 0, blue: 0)
        guard !colors.isEmpty else { return pure }

        let count = Double(colors.count)
        let background = WallpaperRGB(
            red: colors.reduce(0) { $0 + $1.red } / count,
            green: colors.reduce(0) { $0 + $1.green } / count,
            blue: colors.reduce(0) { $0 + $1.blue } / count
        )
        let backgroundLab = oklab(from: background)
        let chroma = min(backgroundLab.chroma * chromaScale, maximumChroma)
        let hue = backgroundLab.hueRadians
        let tintedLightness = appearance == .dark ? tintedLightLightness : tintedDarkLightness
        let extremeLightness = appearance == .dark ? 1.0 : 0.0

        func candidate(_ progress: Double) -> WallpaperRGB {
            let lightness = tintedLightness + (extremeLightness - tintedLightness) * progress
            let scaledChroma = chroma * (1 - progress)
            return rgb(from: OKLab(
                lightness: lightness,
                a: scaledChroma * cos(hue),
                b: scaledChroma * sin(hue)
            ))
        }

        func meetsTarget(_ text: WallpaperRGB) -> Bool {
            colors.allSatisfy {
                WallpaperAppearanceSelection.contrastRatio(
                    foregroundLuminance: text.relativeLuminance,
                    backgroundLuminance: $0.relativeLuminance
                ) >= minimumContrastRatio
            }
        }

        if meetsTarget(candidate(0)) { return candidate(0) }
        // Even pure black or white may miss the target on mid-tone
        // backgrounds; that is still the maximum achievable contrast.
        guard meetsTarget(candidate(1)) else { return pure }
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<16 {
            let middle = (lower + upper) / 2
            if meetsTarget(candidate(middle)) {
                upper = middle
            } else {
                lower = middle
            }
        }
        return candidate(upper)
    }

    // MARK: - Tool bar colors

    /// OKLab lightness of trend-bar segments over dark and light panels.
    static let barLightLightness = 0.8
    static let barDarkLightness = 0.45
    static let barChroma = 0.11

    /// Produces a trend-bar color at a fixed hue whose lightness follows the
    /// panel's text polarity, so per-tool hues stay distinguishable while
    /// matching the wallpaper-adaptive contrast direction. A `nil` hue is
    /// achromatic: near-white over dark panels, dark gray over light panels.
    /// A tool's fixed brand color when it defines one, otherwise the
    /// polarity-adaptive hue rendering below.
    static func barColor(
        for tool: Tool,
        appearance: PanelSemanticAppearance
    ) -> WallpaperRGB {
        tool.fixedBarColor ?? barColor(hueDegrees: tool.barHueDegrees, appearance: appearance)
    }

    static func barColor(
        hueDegrees: Double?,
        appearance: PanelSemanticAppearance
    ) -> WallpaperRGB {
        let lightness = appearance == .dark ? barLightLightness : barDarkLightness
        guard let hueDegrees else {
            return rgb(from: OKLab(lightness: lightness, a: 0, b: 0))
        }
        let radians = hueDegrees * .pi / 180
        return rgb(from: OKLab(
            lightness: lightness,
            a: barChroma * cos(radians),
            b: barChroma * sin(radians)
        ))
    }

    // MARK: - APCA (APCA-W3 0.1.9 four-parameter model)

    private static let apcaBlackThreshold = 0.022
    private static let apcaBlackClamp = 1.414
    private static let apcaScale = 1.14
    private static let apcaOffset = 0.027
    private static let apcaOutputClamp = 0.1

    static func apcaLuminance(of color: WallpaperRGB) -> Double {
        let luminance = 0.2126729 * pow(color.red, 2.4)
            + 0.7151522 * pow(color.green, 2.4)
            + 0.0721750 * pow(color.blue, 2.4)
        guard luminance < apcaBlackThreshold else { return luminance }
        return luminance + pow(apcaBlackThreshold - luminance, apcaBlackClamp)
    }

    /// APCA lightness contrast Lc. Positive for dark text on a light
    /// background, negative for light text on a dark background.
    static func apcaContrast(textLuminance: Double, backgroundLuminance: Double) -> Double {
        if backgroundLuminance >= textLuminance {
            let contrast = (pow(backgroundLuminance, 0.56) - pow(textLuminance, 0.57)) * apcaScale
            return contrast < apcaOutputClamp ? 0 : (contrast - apcaOffset) * 100
        }
        let contrast = (pow(backgroundLuminance, 0.65) - pow(textLuminance, 0.62)) * apcaScale
        return contrast > -apcaOutputClamp ? 0 : (contrast + apcaOffset) * 100
    }

    // MARK: - OKLab conversions

    static func oklab(from color: WallpaperRGB) -> OKLab {
        let red = sRGBToLinear(color.red)
        let green = sRGBToLinear(color.green)
        let blue = sRGBToLinear(color.blue)
        let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
        let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
        let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
        return OKLab(
            lightness: 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short,
            a: 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short,
            b: 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
        )
    }

    static func rgb(from lab: OKLab) -> WallpaperRGB {
        let long = cube(lab.lightness + 0.3963377774 * lab.a + 0.2158037573 * lab.b)
        let medium = cube(lab.lightness - 0.1055613458 * lab.a - 0.0638541728 * lab.b)
        let short = cube(lab.lightness - 0.0894841775 * lab.a - 1.2914855480 * lab.b)
        return WallpaperRGB(
            red: linearToSRGB(4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short),
            green: linearToSRGB(-1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short),
            blue: linearToSRGB(-0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short)
        )
    }

    private static func cube(_ value: Double) -> Double { value * value * value }

    private static func sRGBToLinear(_ component: Double) -> Double {
        component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
    }

    private static func linearToSRGB(_ component: Double) -> Double {
        let clamped = min(max(component, 0), 1)
        return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
