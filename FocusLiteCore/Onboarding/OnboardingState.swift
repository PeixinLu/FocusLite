import Foundation
import SwiftUI

final class OnboardingState: ObservableObject {
    enum Step: Int, CaseIterable {
        case hotkey
        case overview
        case prefixes
        case appearance
    }

    @Published var isPresented = false
    @Published var currentStep: Step = .hotkey
    @Published var hotkeyStepCompleted = false
    @Published var launcherHotKeyText: String = GeneralPreferences.launcherHotKeyText

    @AppStorage("onboarding.hasSeen")
    var hasSeenOnboarding = false

    func present() {
        currentStep = .hotkey
        hotkeyStepCompleted = false
        launcherHotKeyText = GeneralPreferences.launcherHotKeyText
        isPresented = true
    }

    func dismiss(markSeen: Bool = true) {
        isPresented = false
        if markSeen {
            hasSeenOnboarding = true
        }
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else {
            dismiss(markSeen: true)
            return
        }
        currentStep = next
    }
}
