import SwiftUI

@main
struct FlowMasterApp: App {
    @StateObject private var habitStore = HabitStore()
    @StateObject private var artEngine = ArtEngine()
    @StateObject private var onboardingManager = OnboardingManager()
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(habitStore)
                .environmentObject(artEngine)
                .environmentObject(onboardingManager)
                .preferredColorScheme(colorSchemeValue)
                .tint(.accentColor)
        }
    }
    
    var colorSchemeValue: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingFlow()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: hasCompletedOnboarding)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var habitStore: HabitStore
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("今日", systemImage: "sun.max.fill")
                }
                .tag(0)
            
            HabitsView()
                .tabItem {
                    Label("習慣", systemImage: "repeat.circle.fill")
                }
                .tag(1)
                .badge(habitStore.pendingHabitsCount)
            
            ArtStudioView()
                .tabItem {
                    Label("アート", systemImage: "sparkles")
                }
                .tag(2)
            
            InsightsView()
                .tabItem {
                    Label("分析", systemImage: "chart.xyaxis.line")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gear")
                }
                .tag(4)
        }
    }
}

// MARK: - Today View

struct TodayView: View {
    @EnvironmentObject var habitStore: HabitStore
    @State private var greeting = ""
    @State private var showQuickAdd = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    TodayHeaderView(greeting: greeting)
                        .padding(.horizontal)
                    
                    // 進捗サマリー
                    DailyProgressCard()
                        .padding(.horizontal)
                    
                    // 今日の習慣
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("今日の習慣")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: { showQuickAdd = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.horizontal)
                        
                        if habitStore.todayHabits.isEmpty {
                            EmptyHabitsView()
                                .padding(.horizontal)
                        } else {
                            ForEach(habitStore.todayHabits) { habit in
                                ModernHabitCard(habit: habit)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // モチベーションセクション
                    MotivationCard()
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showQuickAdd) {
                QuickAddHabitSheet()
            }
        }
        .onAppear {
            updateGreeting()
        }
    }
    
    func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        greeting = switch hour {
        case 5..<12: "おはようございます"
        case 12..<17: "こんにちは"
        case 17..<22: "こんばんは"
        default: "お疲れさまです"
        }
    }
}

// MARK: - Today Header

struct TodayHeaderView: View {
    let greeting: String
    @EnvironmentObject var habitStore: HabitStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Daily Progress Card

struct DailyProgressCard: View {
    @EnvironmentObject var habitStore: HabitStore
    
    var completionRate: Double {
        guard !habitStore.todayHabits.isEmpty else { return 0 }
        let completed = habitStore.todayHabits.filter { $0.isCompletedToday }.count
        return Double(completed) / Double(habitStore.todayHabits.count)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日の達成率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                CircularProgressView(progress: completionRate)
                    .frame(width: 80, height: 80)
            }
            
            HStack(spacing: 24) {
                ProgressMetric(
                    icon: "checkmark.circle.fill",
                    value: "\(habitStore.completedTodayCount)",
                    label: "完了",
                    color: .green
                )
                
                ProgressMetric(
                    icon: "clock.fill",
                    value: "\(habitStore.pendingTodayCount)",
                    label: "残り",
                    color: .orange
                )
                
                ProgressMetric(
                    icon: "flame.fill",
                    value: "\(habitStore.totalStreakDays)",
                    label: "連続",
                    color: .red
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Modern Habit Card

struct ModernHabitCard: View {
    let habit: Habit
    @State private var isCompleted = false
    @State private var showingDetail = false
    @State private var isPressed = false
    @EnvironmentObject var habitStore: HabitStore
    
    var body: some View {
        HStack(spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                habit.color.opacity(0.2),
                                habit.color.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: habit.icon)
                    .font(.system(size: 24))
                    .foregroundColor(habit.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(habit.title)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(habit.currentStreak)日", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Label("\(Int(habit.completionRate * 100))%", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // 完了ボタン
            Button(action: toggleCompletion) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            habit.isCompletedToday
                                ? habit.color
                                : Color(.systemGray5)
                        )
                        .frame(width: 72, height: 44)
                    
                    if habit.isCompletedToday {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("完了")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(SpringButtonStyle())
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            HabitDetailView(habit: habit)
        }
    }
    
    func toggleCompletion() {
        withAnimation(.spring()) {
            habitStore.toggleHabitCompletion(habit)
            
            if !habit.isCompletedToday {
                // 完了時のフィードバック
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

// MARK: - Art Studio View

struct ArtStudioView: View {
    @EnvironmentObject var artEngine: ArtEngine
    @EnvironmentObject var habitStore: HabitStore
    @State private var selectedVisualization: VisualizationType = .modern
    @State private var isGenerating = false
    @State private var generatedArt: GeneratedArtwork?
    
    enum VisualizationType: String, CaseIterable {
        case modern = "モダン"
        case particle = "パーティクル"
        case dna = "DNA"
        case fractal = "フラクタル"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヒーローセクション
                    VStack(spacing: 12) {
                        Text("習慣をアートに")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("あなたの継続が美しいビジュアルを生み出します")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // ビジュアライゼーションタイプ選択
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(VisualizationType.allCases, id: \.self) { type in
                                VisualizationTypeCard(
                                    type: type,
                                    isSelected: selectedVisualization == type
                                ) {
                                    selectedVisualization = type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // アートプレビューエリア
                    ArtPreviewArea(
                        visualization: selectedVisualization,
                        generatedArt: generatedArt
                    )
                    .padding(.horizontal)
                    
                    // 生成ボタン
                    GenerateArtButton(isGenerating: $isGenerating) {
                        generateArt()
                    }
                    .padding(.horizontal)
                    
                    // 説明セクション
                    VStack(alignment: .leading, spacing: 16) {
                        Text("仕組み")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(ExplanationItem.items) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.icon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.description)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("アートスタジオ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    func generateArt() {
        isGenerating = true
        
        artEngine.generateArtwork { result in
            withAnimation {
                isGenerating = false
                if case .success(let artwork) = result {
                    generatedArt = artwork
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
            
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ProgressMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Quick Add Sheet

struct QuickAddHabitSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var habitStore: HabitStore
    @State private var habitTitle = ""
    @State private var selectedCategory: HabitCategory = .health
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = Color.blue
    
    let quickTemplates = [
        QuickTemplate(title: "水を飲む", icon: "drop.fill", category: .health, color: .blue),
        QuickTemplate(title: "瞑想", icon: "brain.filled.head.profile", category: .mindfulness, color: .purple),
        QuickTemplate(title: "運動", icon: "figure.run", category: .health, color: .green),
        QuickTemplate(title: "読書", icon: "book.fill", category: .learning, color: .orange),
        QuickTemplate(title: "日記", icon: "pencil.and.list.clipboard", category: .creativity, color: .pink)
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // テンプレート
                VStack(alignment: .leading, spacing: 12) {
                    Text("テンプレートから選ぶ")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(quickTemplates) { template in
                                TemplateCard(template: template) {
                                    habitTitle = template.title
                                    selectedIcon = template.icon
                                    selectedCategory = template.category
                                    selectedColor = template.color
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // カスタム入力
                VStack(alignment: .leading, spacing: 16) {
                    Text("カスタム習慣")
                        .font(.headline)
                    
                    TextField("習慣の名前", text: $habitTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    
                    // アイコンと色選択
                    HStack(spacing: 16) {
                        // アイコン選択
                        Menu {
                            ForEach(IconOption.options, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Label(icon, systemImage: icon)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedIcon)
                                Text("アイコン")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        // 色選択
                        ColorPicker("色", selection: $selectedColor)
                            .labelsHidden()
                            .scaleEffect(1.2)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 追加ボタン
                Button(action: addHabit) {
                    Text("習慣を追加")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: habitTitle.isEmpty 
                                    ? [Color.gray, Color.gray.opacity(0.8)]
                                    : [selectedColor, selectedColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(habitTitle.isEmpty)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("新しい習慣")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func addHabit() {
        let newHabit = Habit(
            title: habitTitle,
            icon: selectedIcon,
            color: selectedColor.toHex() ?? "blue",
            category: selectedCategory
        )
        habitStore.addHabit(newHabit)
        dismiss()
    }
}

// MARK: - Empty States

struct EmptyHabitsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("習慣を追加しよう")
                .font(.headline)
            
            Text("最初の習慣を作成して、\n素晴らしい1日を始めましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Data Models

class HabitStore: ObservableObject {
    @Published var habits: [Habit] = []
    
    var todayHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }
    
    var completedTodayCount: Int {
        todayHabits.filter { $0.isCompletedToday }.count
    }
    
    var pendingTodayCount: Int {
        todayHabits.filter { !$0.isCompletedToday }.count
    }
    
    var pendingHabitsCount: Int {
        pendingTodayCount > 0 ? pendingTodayCount : 0
    }
    
    var totalStreakDays: Int {
        todayHabits.map { $0.currentStreak }.max() ?? 0
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
    }
    
    func toggleHabitCompletion(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].toggleCompletion()
        }
    }
}

class ArtEngine: ObservableObject {
    func generateArtwork(completion: @escaping (Result<GeneratedArtwork, Error>) -> Void) {
        // アート生成のシミュレーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(.success(GeneratedArtwork(id: UUID(), imageData: Data())))
        }
    }
}

class OnboardingManager: ObservableObject {
    @Published var currentPage = 0
    @Published var hasCompletedOnboarding = false
}

struct Habit: Identifiable {
    let id = UUID()
    var title: String
    var icon: String
    var color: Color
    var category: HabitCategory
    var currentStreak: Int = 0
    var completionRate: Double = 0.85
    var isCompletedToday: Bool = false
    var isArchived: Bool = false
    
    init(title: String, icon: String = "star.fill", color: String = "blue", category: HabitCategory = .other) {
        self.title = title
        self.icon = icon
        self.color = Color(hex: color) ?? .blue
        self.category = category
        self.currentStreak = Int.random(in: 0...30)
        self.completionRate = Double.random(in: 0.6...1.0)
    }
    
    mutating func toggleCompletion() {
        isCompletedToday.toggle()
        if isCompletedToday {
            currentStreak += 1
        }
    }
}

enum HabitCategory: String, CaseIterable {
    case health = "健康"
    case mindfulness = "マインドフルネス"
    case learning = "学習"
    case creativity = "創造性"
    case productivity = "生産性"
    case social = "社会"
    case finance = "お金"
    case environment = "環境"
    case other = "その他"
}

struct GeneratedArtwork: Identifiable {
    let id: UUID
    let imageData: Data
}

// MARK: - Supporting Types

struct QuickTemplate: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let category: HabitCategory
    let color: Color
}

struct IconOption {
    static let options = [
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "drop.fill",
        "leaf.fill",
        "brain.filled.head.profile",
        "figure.run",
        "book.fill",
        "pencil.and.list.clipboard",
        "music.note",
        "moon.fill",
        "sun.max.fill",
        "cloud.fill"
    ]
}

struct ExplanationItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    
    static let items = [
        ExplanationItem(
            icon: "chart.line.uptrend.xyaxis",
            title: "データ収集",
            description: "毎日の習慣データを分析"
        ),
        ExplanationItem(
            icon: "cpu",
            title: "DNA生成",
            description: "独自のアルゴリズムでパターン化"
        ),
        ExplanationItem(
            icon: "sparkles",
            title: "アート変換",
            description: "美しいビジュアルアートに変換"
        )
    ]
}

// MARK: - Placeholder Views (実装が必要)

struct HabitsView: View {
    var body: some View {
        NavigationStack {
            Text("習慣一覧")
                .navigationTitle("習慣")
        }
    }
}

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            Text("分析画面")
                .navigationTitle("分析")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("設定画面")
                .navigationTitle("設定")
        }
    }
}

struct OnboardingFlow: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        VStack {
            Text("オンボーディング")
            Button("スキップ") {
                hasCompletedOnboarding = true
            }
        }
    }
}

struct HabitDetailView: View {
    let habit: Habit
    
    var body: some View {
        Text("習慣詳細: \(habit.title)")
    }
}

struct MotivationCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("今日の言葉")
                .font(.headline)
            Text("小さな一歩が、大きな変化を生む")
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

struct VisualizationTypeCard: View {
    let type: ArtStudioView.VisualizationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconForType)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
    
    var iconForType: String {
        switch type {
        case .modern: return "square.grid.3x3.fill"
        case .particle: return "sparkles"
        case .dna: return "waveform.path.ecg"
        case .fractal: return "hurricane"
        }
    }
}

struct ArtPreviewArea: View {
    let visualization: ArtStudioView.VisualizationType
    let generatedArt: GeneratedArtwork?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6))
                .frame(height: 300)
            
            if generatedArt != nil {
                // 生成されたアートを表示
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("習慣データからアートを生成")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct GenerateArtButton: View {
    @Binding var isGenerating: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isGenerating ? "生成中..." : "アートを生成")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isGenerating)
    }
}

struct TemplateCard: View {
    let template: QuickTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.color)
                }
                
                Text(template.title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80)
        }
    }
}

// MARK: - Extensions

extension Color {
    init?(hex: String) {
        // Basic color mapping for now
        switch hex.lowercased() {
        case "blue": self = .blue
        case "purple": self = .purple
        case "pink": self = .pink
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "mint": self = .mint
        case "teal": self = .teal
        case "cyan": self = .cyan
        case "indigo": self = .indigo
        case "brown": self = .brown
        case "gray": self = .gray
        default: return nil
        }
    }
    
    func toHex() -> String? {
        // Simple color to string mapping
        switch self {
        case .blue: return "blue"
        case .purple: return "purple"
        case .pink: return "pink"
        case .red: return "red"
        case .orange: return "orange"
        case .yellow: return "yellow"
        case .green: return "green"
        case .mint: return "mint"
        case .teal: return "teal"
        case .cyan: return "cyan"
        case .indigo: return "indigo"
        case .brown: return "brown"
        case .gray: return "gray"
        default: return "blue"
        }
    }
    
    static var accentColor: Color {
        .blue
    }
}