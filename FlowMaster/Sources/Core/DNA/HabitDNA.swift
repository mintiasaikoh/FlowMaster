import Foundation
import Accelerate
import CoreML

/// 習慣データから生成される独自のDNA配列
/// 各習慣の特性を数学的に表現し、ユニークなアートパラメータに変換
public struct HabitDNA {
    
    /// DNAの基本要素（ATCG + 拡張要素）
    enum Nucleotide: CaseIterable {
        case adenine    // 達成率
        case thymine    // 継続性
        case cytosine   // 強度
        case guanine    // 成長率
        case uracil     // 変動性
        case xanthine   // 創造性
        
        var weight: Float {
            switch self {
            case .adenine: return 1.618  // 黄金比
            case .thymine: return 2.718  // 自然対数の底
            case .cytosine: return 3.141 // 円周率
            case .guanine: return 1.414  // √2
            case .uracil: return 0.577   // オイラー定数
            case .xanthine: return 2.502 // ファイゲンバウム定数
            }
        }
    }
    
    /// DNA配列
    private(set) var sequence: [Nucleotide]
    
    /// 習慣の特性ベクトル
    private(set) var characteristics: SIMD8<Float>
    
    /// 時間による進化係数
    private(set) var evolutionFactor: Float
    
    /// カオス理論に基づく複雑性指標
    private(set) var chaosIndex: Float
    
    /// フラクタル次元
    private(set) var fractalDimension: Float
    
    init(habitData: HabitData) {
        // DNA配列の生成
        self.sequence = HabitDNA.generateSequence(from: habitData)
        
        // 空の配列を避ける
        if self.sequence.isEmpty {
            self.sequence = [.adenine, .thymine, .cytosine, .guanine]
        }
        
        // 特性ベクトルの計算
        self.characteristics = HabitDNA.calculateCharacteristics(habitData)
        
        // 進化係数の計算
        self.evolutionFactor = HabitDNA.calculateEvolution(habitData)
        
        // カオス指標の計算
        self.chaosIndex = HabitDNA.calculateChaos(habitData)
        
        // フラクタル次元の計算
        self.fractalDimension = HabitDNA.calculateFractalDimension(habitData)
    }
    
    /// 習慣データからDNA配列を生成
    private static func generateSequence(from data: HabitData) -> [Nucleotide] {
        var sequence: [Nucleotide] = []
        
        // 達成率に基づくアデニン生成
        let adenineCount = max(0, min(100, Int(data.completionRate * 100)))
        if adenineCount > 0 {
            sequence.append(contentsOf: Array(repeating: .adenine, count: adenineCount))
        }
        
        // 継続日数に基づくチミン生成
        let thymineCount = max(0, min(100, data.streakDays))
        if thymineCount > 0 {
            sequence.append(contentsOf: Array(repeating: .thymine, count: thymineCount))
        }
        
        // 習慣の強度に基づくシトシン生成
        let cytosineCount = max(0, min(50, Int(data.intensity * 50)))
        if cytosineCount > 0 {
            sequence.append(contentsOf: Array(repeating: .cytosine, count: cytosineCount))
        }
        
        // 成長率に基づくグアニン生成
        let guanineCount = max(0, min(80, Int(data.growthRate * 80)))
        if guanineCount > 0 {
            sequence.append(contentsOf: Array(repeating: .guanine, count: guanineCount))
        }
        
        // 変動性に基づくウラシル生成
        let variability = calculateVariability(data.history)
        let uracilCount = max(0, min(60, Int(variability * 60)))
        if uracilCount > 0 {
            sequence.append(contentsOf: Array(repeating: .uracil, count: uracilCount))
        }
        
        // 創造性指標に基づくキサンチン生成
        let creativity = calculateCreativity(data)
        let xanthineCount = max(0, min(40, Int(creativity * 40)))
        if xanthineCount > 0 {
            sequence.append(contentsOf: Array(repeating: .xanthine, count: xanthineCount))
        }
        
        // シャッフルアルゴリズムで配列を混合
        var generator = SeededRandomGenerator(seed: data.id.hashValue)
        let shuffled = sequence.shuffled(using: &generator)
        
        // 空の配列を避ける
        return shuffled.isEmpty ? [.adenine, .thymine, .cytosine, .guanine] : shuffled
    }
    
    /// 習慣の特性を8次元ベクトルで表現
    private static func calculateCharacteristics(_ data: HabitData) -> SIMD8<Float> {
        return SIMD8<Float>(
            Float(data.completionRate),           // 達成率
            Float(data.streakDays) / 365.0,       // 年間継続率
            Float(data.intensity),                 // 強度
            Float(data.growthRate),                // 成長率
            Float(calculateVariability(data.history)), // 変動性
            Float(calculateCreativity(data)),      // 創造性
            Float(data.timeOfDay.hour ?? 12) / 24.0,   // 時間帯正規化
            Float(data.category.rawValue) / 10.0  // カテゴリ正規化
        )
    }
    
    /// 時間経過による進化係数を計算
    private static func calculateEvolution(_ data: HabitData) -> Float {
        let daysSinceStart = Float(Date().timeIntervalSince(data.startDate) / 86400)
        let evolutionBase = log(daysSinceStart + 1) / log(365)
        let consistency = Float(data.streakDays) / daysSinceStart
        return evolutionBase * consistency * Float.pi
    }
    
    /// カオス理論に基づく複雑性指標を計算
    private static func calculateChaos(_ data: HabitData) -> Float {
        let history = data.history.map { $0 ? 1.0 : 0.0 }
        guard history.count > 10 else { return 0.5 }
        
        // ロジスティック写像による解析
        var x = 0.5
        let r = 3.57 + 0.43 * data.completionRate // カオスの縁
        
        for value in history {
            x = r * x * (1 - x) + 0.1 * value
        }
        
        return Float(x)
    }
    
    /// フラクタル次元の計算
    private static func calculateFractalDimension(_ data: HabitData) -> Float {
        let history = data.history
        guard history.count > 20 else { return 1.5 }
        
        // ボックスカウント法の簡易実装
        var boxCounts: [Int: Int] = [:]
        let scales = [1, 2, 4, 8, 16]
        
        for scale in scales {
            var count = 0
            for i in stride(from: 0, to: history.count, by: scale) {
                let endIndex = min(i + scale, history.count)
                let slice = history[i..<endIndex]
                if slice.contains(true) {
                    count += 1
                }
            }
            boxCounts[scale] = count
        }
        
        // 線形回帰でフラクタル次元を推定
        let logScales = scales.map { log(Float(max(1, $0))) }
        let logCounts = scales.compactMap { boxCounts[$0] }.map { log(Float(max(1, $0))) }
        
        // 簡易的な傾き計算
        let n = Float(logScales.count)
        let sumX = logScales.reduce(0, +)
        let sumY = logCounts.reduce(0, +)
        let sumXY = zip(logScales, logCounts).map(*).reduce(0, +)
        let sumX2 = logScales.map { $0 * $0 }.reduce(0, +)
        
        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 1.5 }
        
        let slope = (n * sumXY - sumX * sumY) / denominator
        
        return abs(slope)
    }
    
    private static func calculateVariability(_ history: [Bool]) -> Float {
        guard history.count > 1 else { return 0 }
        
        var changes = 0
        for i in 1..<history.count {
            if history[i] != history[i-1] {
                changes += 1
            }
        }
        
        return Float(changes) / Float(max(1, history.count - 1))
    }
    
    private static func calculateCreativity(_ data: HabitData) -> Float {
        // 習慣の多様性と変化から創造性を推定
        let timeVariance = calculateTimeVariance(data.timestamps)
        let categoryUniqueness = 1.0 / Float(max(1, data.category.frequency))
        let evolutionSpeed = data.growthRate * data.completionRate
        
        return (timeVariance + categoryUniqueness + Float(evolutionSpeed)) / 3.0
    }
    
    private static func calculateTimeVariance(_ timestamps: [Date]) -> Float {
        guard timestamps.count > 1 else { return 0 }
        
        let intervals = zip(timestamps.dropLast(), timestamps.dropFirst()).map {
            Float($1.timeIntervalSince($0))
        }
        
        guard !intervals.isEmpty else { return 0 }
        
        let mean = intervals.reduce(0, +) / Float(intervals.count)
        guard mean > 0 else { return 0 }
        
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Float(intervals.count)
        
        return sqrt(variance) / mean
    }
}

/// アートパラメータへの変換
extension HabitDNA {
    
    /// パーティクルシステムのパラメータを生成
    func generateParticleParameters() -> ParticleParameters {
        let baseCount = sequence.filter { $0 == .adenine }.count
        let energyLevel = sequence.filter { $0 == .thymine }.count
        
        return ParticleParameters(
            count: max(1, baseCount * Int(max(0.1, evolutionFactor) * 1000)),
            energy: Float(energyLevel) * max(0.1, chaosIndex),
            colorHue: characteristics[5] * 360,  // 創造性を色相に
            spread: max(1, fractalDimension * 100),
            gravity: characteristics[2] * -9.81,  // 強度を重力に
            turbulence: max(0, chaosIndex * 10),
            lifespan: max(0.1, evolutionFactor * 5)
        )
    }
    
    /// シェーダーのパラメータを生成
    func generateShaderParameters() -> ShaderParameters {
        let frequencies = sequence.map { $0.weight }
        let fft = performFFT(on: frequencies)
        
        return ShaderParameters(
            waveAmplitudes: fft.prefix(8).map { Float($0) },
            colorGradient: generateColorGradient(),
            distortionFactor: chaosIndex,
            fractalIterations: Int(fractalDimension * 10),
            timeScale: evolutionFactor
        )
    }
    
    /// 色のグラデーションを生成
    private func generateColorGradient() -> [SIMD4<Float>] {
        var colors: [SIMD4<Float>] = []
        
        for i in 0..<8 {
            let hue = Float(i) / 8.0 + characteristics[5]
            let saturation = 0.7 + 0.3 * characteristics[2]
            let brightness = 0.8 + 0.2 * characteristics[0]
            
            let rgb = hsbToRGB(h: hue, s: saturation, b: brightness)
            colors.append(SIMD4<Float>(rgb.0, rgb.1, rgb.2, 1.0))
        }
        
        return colors
    }
    
    private func hsbToRGB(h: Float, s: Float, b: Float) -> (Float, Float, Float) {
        let c = b * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = b - c
        
        let h6 = Int(h * 6) % 6
        let (r, g, b): (Float, Float, Float) = switch h6 {
        case 0: (c, x, 0)
        case 1: (x, c, 0)
        case 2: (0, c, x)
        case 3: (0, x, c)
        case 4: (x, 0, c)
        default: (c, 0, x)
        }
        
        return (r + m, g + m, b + m)
    }
    
    private func performFFT(on values: [Float]) -> [Float] {
        // 簡易的なFFT実装（実際はAccelerateフレームワークを使用）
        return values
    }
}

/// シード付きランダムジェネレータ
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: Int) {
        // 負の値を正の値に変換
        self.state = UInt64(bitPattern: Int64(seed))
    }
    
    mutating func next() -> UInt64 {
        state = state &* 2862933555777941757 &+ 3037000493
        return state
    }
}

/// 習慣データモデル
struct HabitData {
    let id: UUID
    let name: String
    let category: DNAHabitCategory
    let startDate: Date
    let completionRate: Double
    let streakDays: Int
    let intensity: Double
    let growthRate: Double
    let history: [Bool]
    let timestamps: [Date]
    let timeOfDay: DateComponents
}

enum DNAHabitCategory: Int, CaseIterable {
    case health = 1
    case creativity = 2
    case learning = 3
    case productivity = 4
    case mindfulness = 5
    case social = 6
    case finance = 7
    case environment = 8
    
    var frequency: Int {
        switch self {
        case .health: return 1
        case .creativity: return 3
        case .learning: return 2
        case .productivity: return 1
        case .mindfulness: return 4
        case .social: return 5
        case .finance: return 6
        case .environment: return 8
        }
    }
}

/// パーティクルシステムのパラメータ
struct ParticleParameters {
    let count: Int
    let energy: Float
    let colorHue: Float
    let spread: Float
    let gravity: Float
    let turbulence: Float
    let lifespan: Float
}

/// シェーダーパラメータ
struct ShaderParameters {
    let waveAmplitudes: [Float]
    let colorGradient: [SIMD4<Float>]
    let distortionFactor: Float
    let fractalIterations: Int
    let timeScale: Float
}