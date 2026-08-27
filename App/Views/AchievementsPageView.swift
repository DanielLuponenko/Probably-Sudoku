import SwiftUI

/// A physical progress page in the current Book. Unearned entries stay visible
/// and specific so players can choose a goal without consulting a hidden list
/// or being signed into Game Center.
struct AchievementsPageView: View {
    @Environment(PlayerProfileStore.self) private var profile
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(AchievementCategory.allCases) { category in
                        let achievements = AchievementCatalog.all.filter { $0.category == category }
                        AchievementSection(category: category, achievements: achievements,
                                           earnedIDs: profile.profile.earnedAchievementIDs)
                    }
                }
                .padding(.bottom, 4)
            }

            PaperButton(title: "Back to the Book", kind: .quiet, action: onBack)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements").pageHeading(30)
                Spacer()
                Text("\(profile.profile.earnedAchievementIDs.count) / \(AchievementCatalog.all.count)")
                    .font(Print.numeral(15, weight: .bold))
                    .foregroundStyle(Paper.sageDeep)
                    .accessibilityLabel("\(profile.profile.earnedAchievementIDs.count) of \(AchievementCatalog.all.count) achievements earned")
            }
            Text("Your progress lives here first. Game Center catches up when it can.")
                .font(Print.body(12.5))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Paper.rule).frame(height: 1)
        }
    }
}

private struct AchievementSection: View {
    var category: AchievementCategory
    var achievements: [AchievementDefinition]
    var earnedIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(category.rawValue)
                .font(Print.caption(11)).tracking(1.5).textCase(.uppercase)
                .foregroundStyle(Paper.inkSoft)

            ForEach(achievements) { achievement in
                AchievementRow(achievement: achievement,
                               isEarned: earnedIDs.contains(achievement.id))
            }
        }
    }
}

private struct AchievementRow: View {
    var achievement: AchievementDefinition
    var isEarned: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isEarned ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isEarned ? Paper.sageDeep : Paper.inkFaint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(Print.subheading(13.5))
                    .foregroundStyle(isEarned ? Paper.ink : Paper.inkSoft)
                Text(achievement.detail)
                    .font(Print.body(11.5))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 4).fill(isEarned ? Paper.pageWarm : Paper.page))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isEarned ? Paper.sageDeep.opacity(0.55) : Paper.rule.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title). \(achievement.detail). \(isEarned ? "Earned" : "Not earned")")
    }
}
