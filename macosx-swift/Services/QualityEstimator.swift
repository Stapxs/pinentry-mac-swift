import Foundation

struct PassphraseQualityAssessment: Equatable {
    enum Grade: String, Equatable {
        case weak
        case fair
        case good
        case strong
    }

    let score: Double
    let grade: Grade

    var label: String {
        L10n.qualityLabel(for: grade)
    }
}

protocol PassphraseQualityEstimating {
    func evaluate(passphrase: String) -> PassphraseQualityAssessment?
}

struct HeuristicQualityEstimator: PassphraseQualityEstimating {
    func evaluate(passphrase: String) -> PassphraseQualityAssessment? {
        guard !passphrase.isEmpty else {
            return nil
        }

        var score = min(Double(passphrase.count) / 18.0, 0.55)
        if passphrase.rangeOfCharacter(from: .uppercaseLetters) != nil {
            score += 0.15
        }
        if passphrase.rangeOfCharacter(from: .decimalDigits) != nil {
            score += 0.15
        }
        if passphrase.rangeOfCharacter(from: CharacterSet.punctuationCharacters.union(.symbols)) != nil {
            score += 0.15
        }

        let normalizedScore = min(score, 1.0)
        let grade: PassphraseQualityAssessment.Grade

        switch normalizedScore {
        case 0.85...:
            grade = .strong
        case 0.55...:
            grade = .good
        case 0.3...:
            grade = .fair
        default:
            grade = .weak
        }

        return PassphraseQualityAssessment(score: normalizedScore, grade: grade)
    }
}
