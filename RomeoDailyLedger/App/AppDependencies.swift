import Observation

@MainActor @Observable
final class AppDependencies {
    var selectedDestination: SidebarDestination
    var themeMode: ThemeMode
    var typographyStyle: AppTypography.Style
    var motionIntensity: Int

    init(selectedDestination: SidebarDestination = .ledger, themeMode: ThemeMode = .system, typographyStyle: AppTypography.Style = .system, motionIntensity: Int = 50) {
        self.selectedDestination = selectedDestination
        self.themeMode = themeMode
        self.typographyStyle = typographyStyle
        self.motionIntensity = min(max(motionIntensity, 0), 100)
    }
}
