import SwiftUI
import WidgetKit

struct EssentialLauncherTimelineEntry: TimelineEntry {
  let date: Date
  let state: LauncherWidgetContentState
}

struct EssentialLauncherProvider: TimelineProvider {
  private let reader = LauncherWidgetDataReader()

  func placeholder(in context: Context) -> EssentialLauncherTimelineEntry {
    EssentialLauncherTimelineEntry(date: Date(), state: .configured(Self.previewEntries))
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (EssentialLauncherTimelineEntry) -> Void
  ) {
    let state: LauncherWidgetContentState = context.isPreview
      ? .configured(Self.previewEntries)
      : reader.load()
    completion(EssentialLauncherTimelineEntry(date: Date(), state: state))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<EssentialLauncherTimelineEntry>) -> Void
  ) {
    let entry = EssentialLauncherTimelineEntry(date: Date(), state: reader.load())
    completion(Timeline(entries: [entry], policy: .atEnd))
  }

  static let previewEntries: [SharedLauncherEntry] = [
    SharedLauncherEntry(id: "preview-phone", name: "Phone", launchUrl: "tel:"),
    SharedLauncherEntry(id: "preview-messages", name: "Messages", launchUrl: "sms:"),
    SharedLauncherEntry(id: "preview-calendar", name: "Calendar", launchUrl: "calshow:"),
    SharedLauncherEntry(id: "preview-music", name: "Music", launchUrl: "music:")
  ]
}

struct EssentialLauncherWidgetView: View {
  @Environment(\.widgetFamily) private var family

  let entry: EssentialLauncherTimelineEntry

  var body: some View {
    content
      .widgetBackground()
      .widgetURL(entry.state.isActionableEmptyState ? LauncherWidgetRoute.setupURL() : nil)
  }

  @ViewBuilder
  private var content: some View {
    switch entry.state {
    case .configured(let entries):
      launcherList(entries: LauncherWidgetDisplayPolicy.selectedEntries(from: entries, family: family))
    case .empty:
      emptyState(
        title: "Choose essential apps",
        message: "Open the app to set up this widget."
      )
    case .unavailable:
      emptyState(
        title: "Open the app",
        message: "Widget sharing needs to be enabled."
      )
    case .corrupt, .unsupportedVersion:
      emptyState(
        title: "Refresh your widget",
        message: "Open the app to rebuild your shortcuts."
      )
    }
  }

  private func launcherList(entries: [SharedLauncherEntry]) -> some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      Text("Essential Apps")
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
        .lineLimit(1)

      ForEach(entries, id: \.id) { item in
        if let url = LauncherWidgetRoute.launchURL(for: item.id) {
          Link(destination: url) {
            LauncherWidgetRow(entry: item)
          }
          .accessibilityLabel(Text("Open \(item.name)"))
          .accessibilityHint(Text("Opens this shortcut through Dumbphone."))
        }
      }

      Spacer(minLength: 0)
    }
    .padding(widgetPadding)
  }

  private func emptyState(title: String, message: String) -> some View {
    Group {
      if let setupURL = LauncherWidgetRoute.setupURL() {
        Link(destination: setupURL) {
          emptyStateLabel(title: title, message: message)
        }
      } else {
        emptyStateLabel(title: title, message: message)
      }
    }
    .accessibilityLabel(Text(title))
    .accessibilityHint(Text(message))
  }

  private func emptyStateLabel(title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Spacer(minLength: 0)
        Text(title)
          .font(.headline.weight(.semibold))
          .foregroundColor(.primary)
        .lineLimit(2)
        Text(message)
          .font(.caption)
          .foregroundColor(.secondary)
        .lineLimit(3)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(widgetPadding)
  }

  private var widgetPadding: EdgeInsets {
    family == .systemLarge
      ? EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
      : EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
  }

  private var rowSpacing: CGFloat {
    family == .systemLarge ? 8 : 6
  }
}

struct LauncherWidgetRow: View {
  let entry: SharedLauncherEntry

  var body: some View {
    HStack(spacing: 10) {
      Text(entry.name)
        .font(.body.weight(.medium))
        .foregroundColor(.primary)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 8)
      Image(systemName: "arrow.up.forward")
        .font(.caption.weight(.semibold))
        .foregroundColor(.secondary)
        .accessibilityHidden(true)
    }
    .frame(minHeight: 34)
    .contentShape(Rectangle())
  }
}

extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(Color(.systemBackground), for: .widget)
    } else {
      background(Color(.systemBackground))
    }
  }
}

struct EssentialLauncherWidget: Widget {
  let kind = SharedLauncherConstants.widgetKind

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: EssentialLauncherProvider()) { entry in
      EssentialLauncherWidgetView(entry: entry)
    }
    .configurationDisplayName("Essential Apps")
    .description("A quiet text launcher for your selected shortcuts.")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}

@main
struct EssentialLauncherWidgetBundle: WidgetBundle {
  var body: some Widget {
    EssentialLauncherWidget()
  }
}
