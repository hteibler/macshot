import SwiftUI

struct FilterListEditor: View {
    @Binding var filters: [FilterRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach($filters) { $filter in
                HStack {
                    TextField("", text: $filter.search, prompt: Text("search"))
                        .textFieldStyle(.roundedBorder)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    TextField("", text: $filter.replace, prompt: Text("replace"))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        filters.removeAll { $0.id == filter.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                filters.append(FilterRule(search: "", replace: ""))
            } label: {
                Label("Add Filter", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
    }
}
