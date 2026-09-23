import WidgetKit
import SwiftUI

struct StorageWidgetEntry: TimelineEntry {
    let date: Date
    let usedBytes: Int64
    let totalBytes: Int64
    
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
            totalBytes: 128 * 1024 * 1024 * 1024
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
                totalBytes: total
            )
        } catch {
            return StorageWidgetEntry(
                date: Date(),
                usedBytes: 60 * 1024 * 1024 * 1024,
                totalBytes: 128 * 1024 * 1024 * 1024
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(Color.green)
                    .font(.caption)
                Text("CleanSpace")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(entry.usedPercentage * 100))% Used")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(ByteCountFormatter.string(fromByteCount: entry.usedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))")
                    .font(.caption2)
                    .foregroundColor(Color.gray)
            }
            
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.35))
                        .frame(height: 7)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * CGFloat(entry.usedPercentage)), height: 7)
                }
            }
            .frame(height: 7)
        }
        .containerBackground(for: .widget) {
            Color(red: 0.12, green: 0.13, blue: 0.16)
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
                        .foregroundColor(Color.gray)
                }
                
                Spacer()
                
                Text("\(ByteCountFormatter.string(fromByteCount: entry.usedBytes, countStyle: .file)) Used")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Total Capacity: \(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(Color.gray)
                
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.35))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, proxy.size.width * CGFloat(entry.usedPercentage)), height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(entry.usedPercentage))
                        .stroke(
                            LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                    Text("\(Int(entry.usedPercentage * 100))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("Storage")
                    .font(.caption2)
                    .foregroundColor(Color.gray)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.12, green: 0.13, blue: 0.16)
        }
    }
}

@main
struct CleanSpaceWidgetBundle: WidgetBundle {
    var body: some Widget {
        CleanSpaceWidget()
    }
}

struct CleanSpaceWidget: Widget {
    let kind: String = "com.cleanspace.app.CleanSpaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CleanSpaceWidgetProvider()) { entry in
            CleanSpaceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Storage Status")
        .description("Track your iPhone storage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
