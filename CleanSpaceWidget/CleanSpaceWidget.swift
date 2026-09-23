import WidgetKit
import SwiftUI

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let usedBytes: Int64
    let totalBytes: Int64
    let cleanableBytes: Int64
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

struct CleanSpaceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StorageWidgetEntry {
        StorageWidgetEntry(
            date: Date(),
            usedBytes: 85 * 1024 * 1024 * 1024,
            totalBytes: 128 * 1024 * 1024 * 1024,
            cleanableBytes: 4 * 1024 * 1024 * 1024
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StorageWidgetEntry) -> Void) {
        let entry = currentStorageEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StorageWidgetEntry>) -> Void) {
        let entry = currentStorageEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func currentStorageEntry() -> StorageWidgetEntry {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacity ?? 0)
            let used = max(0, total - available)
            
            return StorageWidgetEntry(
                date: Date(),
                usedBytes: used,
                totalBytes: total,
                cleanableBytes: 0
            )
        } catch {
            return StorageWidgetEntry(
                date: Date(),
                usedBytes: 60 * 1024 * 1024 * 1024,
                totalBytes: 128 * 1024 * 1024 * 1024,
                cleanableBytes: 0
            )
        }
    }
}

struct CleanSpaceWidgetEntryView: View {
    var entry: StorageWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        default:
            smallWidgetView
        }
    }
    
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(Color.green)
                Text("CleanSpace")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Spacer()
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green)
                    .frame(width: max(8, 120 * CGFloat(entry.usedPercentage)), height: 8)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(entry.usedPercentage * 100))% Used")
                    .font(.subheadline.bold())
                Text("\(ByteCountFormatter.string(fromByteCount: entry.usedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
    
    private var mediumWidgetView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(Color.green)
                    Text("CleanSpace Storage")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(ByteCountFormatter.string(fromByteCount: entry.usedBytes, countStyle: .file)) Used")
                    .font(.title2.bold())
                
                Text("Total Capacity: \(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: max(8, 180 * CGFloat(entry.usedPercentage)), height: 8)
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 65, height: 65)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(entry.usedPercentage))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 65, height: 65)
                    Text("\(Int(entry.usedPercentage * 100))%")
                        .font(.caption.bold())
                }
                
                Text("Storage")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color.black
        }
    }
}

@main
struct CleanSpaceWidget: Widget {
    let kind: String = "CleanSpaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CleanSpaceWidgetProvider()) { entry in
            CleanSpaceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Storage Status")
        .description("Track your iPhone storage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
