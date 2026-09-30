import SwiftUI

struct LicensesView: View {
    var body: some View {
        ScrollView {
            Text(notices).font(.footnote).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding()
        }.navigationTitle("오픈소스 라이선스").navigationBarTitleDisplayMode(.inline)
    }
    private var notices: String {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "라이선스 파일을 불러올 수 없어요." }
        return content
    }
}
