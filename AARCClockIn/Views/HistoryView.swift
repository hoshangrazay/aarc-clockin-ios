import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: ClockViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var history: HistoryResponse?

    var body: some View {
        NavigationStack {
            Group {
                if let h = history, h.ok {
                    List {
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Time")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(h.totalTime ?? "0h 0m")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(red: 0.18, green: 0.65, blue: 0.4))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Days Worked")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(h.totalDays ?? 0)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(red: 0.18, green: 0.65, blue: 0.4))
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        if let days = h.history {
                            Section("Daily Records") {
                                ForEach(days) { day in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(day.date)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        HStack {
                                            Label(day.clockIn ?? "-", systemImage: "arrow.right.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("→")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Label(day.clockOut ?? "active", systemImage: "arrow.left.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(day.duration ?? "-")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            if let m = day.method, m != "manual" {
                                                Text(m.replacingOccurrences(of: "_", with: " "))
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.15))
                                                    .foregroundColor(.purple)
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading history...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Work History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            guard let token = viewModel.session.token else { return }
            history = try? await ClockApi.shared.history(token: token)
        }
    }
}
