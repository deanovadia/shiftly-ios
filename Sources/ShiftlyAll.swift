//
// Shiftly — Single-file source (SwiftUI + SwiftData)
// iOS 17+, Xcode 16+
//

import SwiftUI
import SwiftData
import Foundation
import PDFKit
import UIKit
#if !SIDELOAD
import ActivityKit
#endif
import WidgetKit

// MARK: - App Entry
@main
struct ShiftlyApp: App {
    @State private var container: ModelContainer

    init() {
        self._container = State(wrappedValue: Persistence.makeContainer())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "stopwatch.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "calendar") }
            NavigationStack { InsightsView() }
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Persistence / SwiftData
enum Persistence {
    static let cloudKitID = "iCloud.com.example.shiftly" // not used for SIDELOAD builds

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Shift.self, ShiftBreak.self, RateBlock.self, Settings.self, AutoBreakRule.self])
        #if SIDELOAD
        let config = ModelConfiguration()
        #else
        let config = ModelConfiguration(cloudKitDatabase: .automatic, cloudKitContainerIdentifier: cloudKitID)
        #endif
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}

// MARK: - Theme
struct Theme {
    static let bg = Color(hex: 0x0B0F14)
    static let surface = Color(hex: 0x11161C)
    static let surface2 = Color(hex: 0x151B23)
    static let primary = Color(hex: 0x69D5FF)
    static let success = Color(hex: 0x8BEA7B)
    static let warning = Color(hex: 0xFFC86B)
    static let textPrimary = Color(hex: 0xEAF1F7)
    static let textSecondary = Color(hex: 0xAAB7C7)
    static let border = Color(hex: 0x1E2630)
}

// MARK: - Models
@Model final class Shift {
    @Attribute(.unique) var id: UUID
    var startAt: Date
    var endAt: Date?
    var plannedEndAt: Date?
    var notes: String?
    var tags: [String]
    var currencyCode: String
    @Relationship(deleteRule: .cascade, inverse: \ShiftBreak.shift) var breaks: [ShiftBreak]
    @Relationship(deleteRule: .cascade, inverse: \RateBlock.shift) var rateBlocks: [RateBlock]
    var tipsAmount: Decimal?

    init(id: UUID = UUID(), startAt: Date, endAt: Date? = nil, plannedEndAt: Date? = nil, notes: String? = nil, tags: [String] = [], currencyCode: String) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.plannedEndAt = plannedEndAt
        self.notes = notes
        self.tags = tags
        self.currencyCode = currencyCode
        self.breaks = []
        self.rateBlocks = []
    }
}

@Model final class ShiftBreak {
    @Attribute(.unique) var id: UUID
    var start: Date
    var end: Date?
    var isPaid: Bool
    @Relationship var shift: Shift?

    init(id: UUID = UUID(), start: Date, end: Date? = nil, isPaid: Bool, shift: Shift? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.isPaid = isPaid
        self.shift = shift
    }
}

@Model final class RateBlock {
    @Attribute(.unique) var id: UUID
    var start: Date
    var end: Date?
    var ratePerHour: Decimal
    var multiplier: Double
    @Relationship var shift: Shift?

    init(id: UUID = UUID(), start: Date, end: Date? = nil, ratePerHour: Decimal, multiplier: Double = 1.0, shift: Shift? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.ratePerHour = ratePerHour
        self.multiplier = multiplier
        self.shift = shift
    }
}

@Model final class Settings {
    @Attribute(.unique) var id: UUID
    var defaultRate: Decimal
    var currencyCode: String
    var symbolOnRight: Bool
    var flipTickInterval: Double
    var dailyOvertimeThresholdHours: Double?
    var dailyOvertimeMultiplier: Double
    var weeklyOvertimeThresholdHours: Double?
    var weeklyOvertimeMultiplier: Double
    @Relationship(deleteRule: .cascade) var autoBreaks: [AutoBreakRule]
    var progressModeRaw: Int
    var targetHours: Double
    var notifyStart: Bool
    var notifyBreak: Bool
    var notifyApproachingEnd: Bool
    var notifyOvertime: Bool
    var iCloudEnabled: Bool

    init(id: UUID = UUID(),
         defaultRate: Decimal = 125,
         currencyCode: String = Locale.current.currency?.identifier ?? "ILS",
         symbolOnRight: Bool = true,
         flipTickInterval: Double = 1.0,
         dailyOvertimeThresholdHours: Double? = 8.0,
         dailyOvertimeMultiplier: Double = 1.25,
         weeklyOvertimeThresholdHours: Double? = nil,
         weeklyOvertimeMultiplier: Double = 1.5,
         autoBreaks: [AutoBreakRule] = [],
         progressModeRaw: Int = 0,
         targetHours: Double = 8.0,
         notifyStart: Bool = false,
         notifyBreak: Bool = true,
         notifyApproachingEnd: Bool = true,
         notifyOvertime: Bool = true,
         iCloudEnabled: Bool = true) {
        self.id = id
        self.defaultRate = defaultRate
        self.currencyCode = currencyCode
        self.symbolOnRight = symbolOnRight
        self.flipTickInterval = flipTickInterval
        self.dailyOvertimeThresholdHours = dailyOvertimeThresholdHours
        self.dailyOvertimeMultiplier = dailyOvertimeMultiplier
        self.weeklyOvertimeThresholdHours = weeklyOvertimeThresholdHours
        self.weeklyOvertimeMultiplier = weeklyOvertimeMultiplier
        self.autoBreaks = autoBreaks
        self.progressModeRaw = progressModeRaw
        self.targetHours = targetHours
        self.notifyStart = notifyStart
        self.notifyBreak = notifyBreak
        self.notifyApproachingEnd = notifyApproachingEnd
        self.notifyOvertime = notifyOvertime
        self.iCloudEnabled = iCloudEnabled
    }
}

@Model final class AutoBreakRule {
    @Attribute(.unique) var id: UUID
    var afterHours: Double
    var durationMinutes: Int
    var isPaid: Bool

    init(id: UUID = UUID(), afterHours: Double, durationMinutes: Int, isPaid: Bool) {
        self.id = id
        self.afterHours = afterHours
        self.durationMinutes = durationMinutes
        self.isPaid = isPaid
    }
}

// MARK: - Calculations
struct OvertimeRules {
    let dailyThreshold: Double?
    let dailyMultiplier: Double
    let weeklyThreshold: Double?
    let weeklyMultiplier: Double
}

struct ShiftTotals {
    var durationHours: Double
    var baseEarnings: Decimal
    var overtimeEarnings: Decimal
    var totalEarnings: Decimal
}

enum ShiftCalcError: Error { case missingEndTime }

struct ShiftCalculator {
    static func unpaidBreakSeconds(_ shift: Shift, upTo end: Date? = nil) -> TimeInterval {
        let e = end ?? shift.endAt ?? Date()
        return shift.breaks.reduce(0.0) { acc, b in
            guard !b.isPaid else { return acc }
            let bs = b.start
            let be = b.end ?? e
            let clipped = max(0, min(e.timeIntervalSince1970, be.timeIntervalSince1970) - bs.timeIntervalSince1970)
            return acc + clipped
        }
    }

    static func durationHours(_ shift: Shift, upTo end: Date? = nil) -> Double {
        let e = end ?? shift.endAt ?? Date()
        let gross = e.timeIntervalSince(shift.startAt)
        let unpaid = unpaidBreakSeconds(shift, upTo: end)
        return max(0, (gross - unpaid) / 3600.0)
    }

    static func compute(shift: Shift, rules: OvertimeRules) throws -> ShiftTotals {
        guard let end = shift.endAt else { throw ShiftCalcError.missingEndTime }
        let totalHours = durationHours(shift, upTo: end)

        var base: Decimal = 0
        var overtime: Decimal = 0

        let blocks = normalizedBlocks(for: shift, upTo: end)
        var remainingRegularHours = rules.dailyThreshold ?? Double.greatestFiniteMagnitude

        for block in blocks {
            let hrs = block.durationHours
            let rate = block.ratePerHour
            let mult = block.multiplier

            if remainingRegularHours > 0 {
                let regular = min(hrs, remainingRegularHours)
                base += (rate * Decimal(regular) * Decimal(mult))
                let over = hrs - regular
                if over > 0 {
                    let overAmt = rate * Decimal(over) * Decimal(rules.dailyMultiplier) * Decimal(mult)
                    overtime += overAmt
                }
                remainingRegularHours -= regular
            } else {
                let overAmt = rate * Decimal(hrs) * Decimal(rules.dailyMultiplier) * Decimal(mult)
                overtime += overAmt
            }
        }

        var total = base + overtime
        if let tips = shift.tipsAmount { total += tips }

        return ShiftTotals(durationHours: totalHours, baseEarnings: base, overtimeEarnings: overtime, totalEarnings: total)
    }

    static func normalizedBlocks(for shift: Shift, upTo end: Date) -> [ConcreteBlock] {
        if shift.rateBlocks.isEmpty {
            return [ConcreteBlock(start: shift.startAt, end: end, ratePerHour: 0, multiplier: 1.0)]
        }
        return shift.rateBlocks.compactMap { rb in
            let s = rb.start
            let e = rb.end ?? end
            guard e > s else { return nil }
            return ConcreteBlock(start: s, end: min(e, end), ratePerHour: rb.ratePerHour, multiplier: rb.multiplier)
        }.sorted { $0.start < $1.start }
    }

    struct ConcreteBlock { let start: Date; let end: Date; let ratePerHour: Decimal; let multiplier: Double
        var durationHours: Double { end.timeIntervalSince(start) / 3600.0 }
    }
}

// MARK: - Formatters & Export
struct MoneyFormatter {
    static func format(_ amount: Decimal, currencyCode: String, symbolOnRight: Bool) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currencyCode
        nf.locale = Locale.current
        let symbol = nf.currencySymbol ?? "?"
        nf.currencySymbol = ""
        let ns = amount as NSDecimalNumber
        let base = nf.string(from: ns) ?? ns.stringValue
        return symbolOnRight ? base + " " + symbol : symbol + " " + base
    }
}

enum Exporter {
    static func csv(shifts: [Shift]) -> String {
        var lines = ["Date,Start,End,Duration (h),Earnings"]
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        for s in shifts.sorted(by: { $0.startAt < $1.startAt }) {
            let end = s.endAt ?? Date()
            let durH = ShiftCalculator.durationHours(s)
            let rules = OvertimeRules(dailyThreshold: 8, dailyMultiplier: 1.25, weeklyThreshold: nil, weeklyMultiplier: 1.5)
            let totals = try? ShiftCalculator.compute(shift: s, rules: rules)
            let earn = totals?.totalEarnings ?? 0
            let durStr = String(format: "%.2f", durH)
            lines.append("\(df.string(from: s.startAt)),\(df.string(from: end)),\(durStr),\(earn)")
        }
        return lines.joined(separator: "\n")
    }

    static func pdf(shifts: [Shift], title: String = "Shiftly Report") -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            NSString(string: title).draw(in: CGRect(x: 40, y: 40, width: pageRect.width - 80, height: 30), withAttributes: titleAttrs)
        }
    }
}

// MARK: - Live Activity (disabled in SIDELOAD builds)
#if !SIDELOAD
struct ShiftActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var currentEarnings: Decimal
    }
    var startAt: Date
    var hourlyRate: Decimal
    var currencyCode: String
}

enum LiveActivityManager {
    static func start(shift: Shift, rate: Decimal) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ShiftActivityAttributes(startAt: shift.startAt, hourlyRate: rate, currencyCode: shift.currencyCode)
        let state = ShiftActivityAttributes.ContentState(elapsedSeconds: 0, currentEarnings: 0)
        do { _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil) } catch { print("Live Activity error: \(error)") }
    }
    static func endAll() {
        Task {
            for activity in Activity<ShiftActivityAttributes>.activities { await activity.end(dismissalPolicy: .immediate) }
        }
    }
}
#endif

// MARK: - Home View + Components
struct HomeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Settings.id) private var settingsList: [Settings]
    @Query(filter: #Predicate<Shift> { $0.endAt == nil }, sort: \Shift.startAt, order: .reverse) private var activeShifts: [Shift]

    @State private var now: Date = Date()
    @State private var timer: Timer?

    private var settings: Settings { settingsList.first ?? Settings() }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(dateHeader(Date())).foregroundStyle(Theme.textSecondary).font(.subheadline)
                Spacer()
                NavigationLink(destination: SettingsView()) { Image(systemName: "gearshape") }
                    .tint(Theme.textSecondary)
            }

            earningsCounter

            if let shift = activeShifts.first {
                progressCard(shift: shift)
            } else {
                Text("tap Clock In to start earning").foregroundStyle(Theme.textSecondary).padding(.top, 4)
            }

            Spacer()
            primaryButton.padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Shiftly")
        .onAppear { startTicker() }
        .onDisappear { stopTicker() }
    }

    private var primaryButton: some View {
        let isActive = activeShifts.first != nil
        return Button(action: { isActive ? clockOut() : clockIn() }) {
            Text(isActive ? "Clock Out" : "Clock In").font(.title2.bold()).padding(.vertical, 16).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isActive ? Theme.warning : Theme.success)
        .clipShape(Capsule())
        .contextMenu { quickActions() }
    }

    @ViewBuilder
    private func progressCard(shift: Shift) -> some View {
        let prog = progressValue(shift: shift)
        let elapsedRem = elapsedRemaining(shift: shift)
        VStack(alignment: .leading, spacing: 10) {
            ProgressBarView(progress: prog)
            HStack {
                Text(elapsedRem.label)
                Spacer()
                Text(elapsedRem.value)
            }.foregroundStyle(Theme.textPrimary)
            Text("Rate \(settings.currencyCode == "ILS" ? "?" : "")\(settings.defaultRate)/hr")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }

    private var earningsCounter: some View {
        let parts = liveEarningsParts()
        return HStack(spacing: 0) {
            ForEach(parts, id: \.self) { ch in
                DigitFlipView(digit: String(ch), fontSize: 58)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.clear)
        .accessibilityLabel("Earnings today")
    }

    private func clockIn() {
        let s = Shift(startAt: Date(), currencyCode: settings.currencyCode)
        let block = RateBlock(start: s.startAt, ratePerHour: settings.defaultRate, multiplier: 1.0, shift: s)
        s.rateBlocks.append(block)
        ctx.insert(s)
        try? ctx.save()
        #if !SIDELOAD
        LiveActivityManager.start(shift: s, rate: settings.defaultRate)
        #endif
        Haptics.trigger(.light)
    }

    private func clockOut() {
        guard let s = activeShifts.first else { return }
        s.endAt = Date()
        try? ctx.save()
        #if !SIDELOAD
        LiveActivityManager.endAll()
        #endif
        Haptics.trigger(.success)
    }

    private func quickActions() -> some View {
        Group {
            Button("Add Break") { addBreak() }
            Button("Add Note") { }
            Button("Adjust Rate") { adjustRate() }
            Button("Manual Entry") { }
        }
    }

    private func addBreak() {
        guard let s = activeShifts.first else { return }
        let b = ShiftBreak(start: Date(), isPaid: false, shift: s)
        s.breaks.append(b)
        try? ctx.save()
    }

    private func adjustRate() {
        guard let s = activeShifts.first else { return }
        if let last = s.rateBlocks.sorted(by: { $0.start < $1.start }).last { last.end = Date() }
        let newRate = settings.defaultRate + 10
        let rb = RateBlock(start: Date(), ratePerHour: newRate, multiplier: 1.0, shift: s)
        s.rateBlocks.append(rb)
        try? ctx.save()
    }

    private func startTicker() {
        stopTicker()
        let interval = max(0.1, settings.flipTickInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in now = Date() }
    }
    private func stopTicker() { timer?.invalidate(); timer = nil }

    private func liveEarningsParts() -> [Character] {
        guard let shift = activeShifts.first else { return Array("0.00") }
        let blocks = ShiftCalculator.normalizedBlocks(for: shift, upTo: now)
        var total: Decimal = 0
        let unpaid = ShiftCalculator.unpaidBreakSeconds(shift, upTo: now)
        let elapsed = now.timeIntervalSince(shift.startAt) - unpaid
        if elapsed <= 0 { return Array("0.00") }
        for b in blocks {
            let end = min(now, b.end)
            let hrs = max(0, end.timeIntervalSince(b.start) / 3600.0)
            total += b.ratePerHour * Decimal(hrs) * Decimal(b.multiplier)
        }
        let str = MoneyFormatter.format(total, currencyCode: shift.currencyCode, symbolOnRight: true)
        return Array(str)
    }

    private func progressValue(shift: Shift) -> Double {
        switch settings.progressModeRaw {
        case 0:
            guard let planned = shift.plannedEndAt else { return 0 }
            let total = planned.timeIntervalSince(shift.startAt)
            let unpaid = ShiftCalculator.unpaidBreakSeconds(shift, upTo: now)
            let done = now.timeIntervalSince(shift.startAt) - unpaid
            return max(0, min(1, total > 0 ? done / total : 0))
        default:
            let target = settings.targetHours
            let done = ShiftCalculator.durationHours(shift, upTo: now)
            return max(0, min(1, target > 0 ? done / target : 0))
        }
    }

    private func elapsedRemaining(shift: Shift) -> (label: String, value: String) {
        let elapsed = ShiftCalculator.durationHours(shift, upTo: now)
        if let planned = shift.plannedEndAt {
            let total = (planned.timeIntervalSince(shift.startAt) / 3600.0)
            let rem = total - elapsed
            if rem >= 0 { return ("Elapsed", hms(elapsed) + " • Remaining " + hms(rem)) }
            else { return ("Overtime", "+" + hms(-rem)) }
        } else {
            return ("Elapsed", hms(elapsed))
        }
    }

    private func hms(_ hours: Double) -> String {
        let totalSec = Int((hours * 3600).rounded())
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        return String(format: "%02dh %02dm", h, m)
    }

    private func dateHeader(_ date: Date) -> String {
        let df = DateFormatter(); df.dateFormat = "EEE • MMM d"; return df.string(from: date)
    }
}

// MARK: - Components
struct DigitFlipView: View {
    let digit: String
    let fontSize: CGFloat
    @State private var flipped = false

    var body: some View {
        Text(digit)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 2)
            .rotation3DEffect(.degrees(flipped ? 360 : 0), axis: (x: 1, y: 0, z: 0))
            .animation(.easeInOut(duration: 0.25), value: digit)
            .onChange(of: digit) { _ in
                flipped.toggle()
            }
    }
}

struct ProgressBarView: View {
    var progress: Double
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                .frame(height: 14)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Theme.primary.opacity(0.8), Theme.primary], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, CGFloat(progress) * geo.size.width), height: 14)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
            }
        }
        .frame(height: 14)
    }
}

// MARK: - History / Insights / Settings
struct HistoryView: View {
    @Query(sort: \Shift.startAt, order: .reverse) var shifts: [Shift]
    var body: some View {
        List {
            ForEach(groupedByMonth(), id: \.key) { month, items in
                Section(header: Text(month).foregroundStyle(Theme.textSecondary)) {
                    ForEach(items, id: \.id) { s in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayString(s.startAt)).foregroundStyle(Theme.textPrimary)
                                Text(timeRange(s)).font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(totalString(s)).foregroundStyle(Theme.textPrimary).monospacedDigit()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("History")
    }
    private func groupedByMonth() -> [(key: String, value: [Shift])] {
        let df = DateFormatter(); df.dateFormat = "LLLL yyyy"
        let groups = Dictionary(grouping: shifts) { df.string(from: $0.startAt) }
        return groups.sorted { $0.key > $1.key }
    }
    private func dayString(_ d: Date) -> String { let df = DateFormatter(); df.dateFormat = "EEE, MMM d"; return df.string(from: d) }
    private func timeRange(_ s: Shift) -> String {
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"
        if let e = s.endAt { return "\(tf.string(from: s.startAt))–\(tf.string(from: e))" } else { return tf.string(from: s.startAt) }
    }
    private func totalString(_ s: Shift) -> String {
        guard let _ = s.endAt else { return MoneyFormatter.format(0, currencyCode: s.currencyCode, symbolOnRight: true) }
        let totals = try? ShiftCalculator.compute(shift: s, rules: OvertimeRules(dailyThreshold: 8, dailyMultiplier: 1.25, weeklyThreshold: nil, weeklyMultiplier: 1.5))
        return MoneyFormatter.format(totals?.totalEarnings ?? 0, currencyCode: s.currencyCode, symbolOnRight: true)
    }
}

struct InsightsView: View {
    @Query(sort: \Shift.startAt) var shifts: [Shift]
    var body: some View {
        let total = aggregate()
        ScrollView {
            VStack(spacing: 16) {
                insightCard(title: "Total (All Time)", value: total.formatted())
            }.padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Insights")
    }
    private func insightCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title.bold()).foregroundStyle(Theme.textPrimary)
        }
        .padding().background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
    }
    private func aggregate() -> Decimal {
        var total: Decimal = 0
        for s in shifts {
            if let _ = s.endAt {
                let t = try? ShiftCalculator.compute(shift: s, rules: OvertimeRules(dailyThreshold: 8, dailyMultiplier: 1.25, weeklyThreshold: nil, weeklyMultiplier: 1.5))
                total += t?.totalEarnings ?? 0
            }
        }
        return total
    }
}

struct SettingsView: View {
    @Query(sort: \Settings.id) private var settingsList: [Settings]
    @Environment(\.modelContext) private var ctx
    var body: some View {
        let s = settingsList.first ?? Settings()
        Form {
            Section("Currency & Rate") {
                TextField("Currency Code", text: Binding(get: { s.currencyCode }, set: { s.currencyCode = $0 }))
                Toggle("Symbol on right", isOn: Binding(get: { s.symbolOnRight }, set: { s.symbolOnRight = $0 }))
                TextField("Default Hourly Rate", value: Binding(get: { s.defaultRate }, set: { s.defaultRate = $0 }), formatter: NumberFormatter())
            }
            Section("Overtime Rules") {
                TextField("Daily Threshold (h)", value: Binding(get: { s.dailyOvertimeThresholdHours ?? 0 }, set: { s.dailyOvertimeThresholdHours = $0 }), formatter: NumberFormatter())
                TextField("Daily Multiplier", value: Binding(get: { s.dailyOvertimeMultiplier }, set: { s.dailyOvertimeMultiplier = $0 }), formatter: NumberFormatter())
            }
            Section("Flip Counter") {
                Picker("Tick Interval", selection: Binding(get: { s.flipTickInterval }, set: { s.flipTickInterval = $0 })) {
                    Text("1s").tag(1.0)
                    Text("0.5s").tag(0.5)
                    Text("0.1s").tag(0.1)
                }
            }
        }
        .navigationTitle("Settings")
        .onDisappear { try? ctx.save() }
    }
}

// MARK: - Haptics
enum HapticStyle { case light, success }
struct Haptics {
    static func trigger(_ style: HapticStyle) {
        #if os(iOS)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }
}

// MARK: - Utilities
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: alpha)
    }
}

extension Decimal {
    static func + (lhs: Decimal, rhs: Decimal) -> Decimal { var l = lhs; var r = rhs; var res = Decimal(); NSDecimalAdd(&res, &l, &r, .plain); return res }
    static func * (lhs: Decimal, rhs: Decimal) -> Decimal { var l = lhs; var r = rhs; var res = Decimal(); NSDecimalMultiply(&res, &l, &r, .plain); return res }
}
