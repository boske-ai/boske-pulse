import BoskePulseCore
import SwiftUI
import WidgetKit

@main
struct BoskePulseWidgetBundle: Widget {
    let kind = "BoskePulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseTimelineProvider()) { entry in
            PulseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Boske Pulse")
        .description("Live Boske production topology.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PulseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        completion(PulseEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        let entry = PulseEntry(date: Date(), snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> ProductionSnapshot? {
        let store = SnapshotStore(appGroupIdentifier: "group.eu.canopystudio.boske.pulse")
        return try? store.read()
    }
}

struct PulseEntry: TimelineEntry {
    let date: Date
    let snapshot: ProductionSnapshot?
}

struct PulseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading) {
            Text("Boske")
                .font(.caption.weight(.bold))
            Text(entry.snapshot?.overall.rawValue.uppercased() ?? "SYNC")
                .font(.title2.weight(.semibold))
            HStack(spacing: 6) {
                ForEach(entry.snapshot?.servers ?? [], id: \.id) { server in
                    Circle()
                        .fill(dotColor(for: server.overall))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.snapshot?.smokeSummary ?? "Awaiting sync")
                .font(.caption)
            ForEach(entry.snapshot?.servers ?? []) { server in
                HStack {
                    Text(server.name)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(server.overall.rawValue)
                        .font(.caption2)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Production")
                .font(.headline)
            ForEach(entry.snapshot?.servers ?? []) { server in
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                    Text("\(server.containersRunning)/\(server.containersTotal) containers · \(server.overall.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func dotColor(for health: OverallHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
