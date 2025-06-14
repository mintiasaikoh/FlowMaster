# ⚠️ DANGER ZONES - 絶対に避けるべきパターン

## 🚫 これらのコードを見たら即座に停止

### 1. タブベースナビゲーション
```swift
// ❌ 絶対ダメ
TabView {
    TodayView()
    HabitsView()
    SettingsView()
}
```

### 2. 習慣リスト中心のUI
```swift
// ❌ 絶対ダメ
List(habits) { habit in
    HabitRowView(habit: habit)
}
```

### 3. 普通のナビゲーション構造
```swift
// ❌ 絶対ダメ
NavigationStack {
    ScrollView {
        // 習慣管理UI
    }
}
```

### 4. Metalを使わないビュー
```swift
// ❌ 絶対ダメ
struct ContentView: View {
    // MetalビューやMTKViewがない
}
```

## ✅ 正しいパターン

### 1. Metalファースト
```swift
// ✅ これが正解
struct ContentView: View {
    var body: some View {
        ZStack {
            MetalArtView() // 最初に来る
            GlassmorphicOverlay() // UIは上に重ねる
        }
    }
}
```

### 2. アート中心の体験
```swift
// ✅ これが正解
struct FlowMasterApp: App {
    var body: some Scene {
        WindowGroup {
            VisualTrinityView() // アートビューがroot
        }
    }
}
```

## 🔴 赤信号ワード
これらの単語を見たら要注意：
- "TodoList"
- "HabitList" 
- "TabView"
- "Settings"
- "Profile"
- "Statistics"

## 🟢 青信号ワード
これらの単語なら正しい方向：
- "Particle"
- "Metal"
- "Shader"
- "DNA"
- "Art"
- "Visual"
- "Trinity"