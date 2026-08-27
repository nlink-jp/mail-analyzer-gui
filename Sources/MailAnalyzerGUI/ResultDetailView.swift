import SwiftUI
import MailAnalyzerGUICore

// Stub — the full detail (badges, indicators) lands in the next commit.
struct ResultDetailView: View {
    let result: AnalysisResult

    var body: some View {
        Text(result.judgment.summary)
            .font(.system(size: 13))
    }
}
