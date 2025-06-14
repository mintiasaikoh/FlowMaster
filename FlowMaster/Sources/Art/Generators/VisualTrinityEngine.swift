import Metal
import MetalKit
import MetalPerformanceShaders
import SwiftUI
import Combine

/// Visual Trinity Architecture - Processing級の表現力をSwiftネイティブで実現
public class VisualTrinityEngine: NSObject {
    
    // MARK: - Metal Components
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // MARK: - Pipelines
    private var particlePipeline: MTLRenderPipelineState!
    private var liquidGlassPipeline: MTLRenderPipelineState!
    private var generativeArtPipeline: MTLComputePipelineState!
    
    // MARK: - Buffers
    private var particleBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var noiseTextureBuffer: MTLBuffer!
    
    // MARK: - Performance
    private let maxParticles = 1_000_000  // 100万パーティクル
    private var currentParticleCount = 0
    
    // MARK: - Art Generation
    private var habitDNA: HabitDNA?
    private var artParameters: ArtGenerationParameters
    private var timeElapsed: Float = 0
    
    // MARK: - Textures
    private var renderTexture: MTLTexture!
    private var noiseTexture: MTLTexture!
    private var feedbackTexture: MTLTexture!
    
    public init(device: MTLDevice) throws {
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            throw EngineError.deviceNotSupported
        }
        self.commandQueue = queue
        
        // カスタムシェーダーライブラリの作成
        let shaderSource = VisualTrinityShaders.combinedShaderSource
        self.library = try device.makeLibrary(source: shaderSource, options: nil)
        
        self.artParameters = ArtGenerationParameters.default
        
        super.init()
        
        try setupPipelines()
        try setupBuffers()
        try setupTextures()
    }
    
    // MARK: - Setup
    
    private func setupPipelines() throws {
        // パーティクルレンダリングパイプライン
        let particleDescriptor = MTLRenderPipelineDescriptor()
        particleDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
        particleDescriptor.fragmentFunction = library.makeFunction(name: "particleFragment")
        particleDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        particleDescriptor.colorAttachments[0].isBlendingEnabled = true
        particleDescriptor.colorAttachments[0].rgbBlendOperation = .add
        particleDescriptor.colorAttachments[0].alphaBlendOperation = .add
        particleDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        particleDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        particleDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        particleDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        particlePipeline = try device.makeRenderPipelineState(descriptor: particleDescriptor)
        
        // Liquid Glass UIパイプライン
        let glassDescriptor = MTLRenderPipelineDescriptor()
        glassDescriptor.vertexFunction = library.makeFunction(name: "liquidGlassVertex")
        glassDescriptor.fragmentFunction = library.makeFunction(name: "liquidGlassFragment")
        glassDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        liquidGlassPipeline = try device.makeRenderPipelineState(descriptor: glassDescriptor)
        
        // ジェネラティブアートコンピュートパイプライン
        guard let generativeFunction = library.makeFunction(name: "generativeArtCompute") else {
            throw EngineError.shaderNotFound
        }
        generativeArtPipeline = try device.makeComputePipelineState(function: generativeFunction)
    }
    
    private func setupBuffers() throws {
        // パーティクルバッファ（100万パーティクル対応）
        let particleSize = MemoryLayout<Particle>.stride * maxParticles
        guard let buffer = device.makeBuffer(length: particleSize, options: [.storageModeShared]) else {
            throw EngineError.bufferCreationFailed
        }
        particleBuffer = buffer
        
        // ユニフォームバッファ
        let uniformSize = MemoryLayout<Uniforms>.stride
        guard let uniformBuf = device.makeBuffer(length: uniformSize, options: [.storageModeShared]) else {
            throw EngineError.bufferCreationFailed
        }
        uniformBuffer = uniformBuf
        
        // ノイズテクスチャバッファ
        let noiseSize = 512 * 512 * 4 * MemoryLayout<Float>.stride
        guard let noiseBuf = device.makeBuffer(length: noiseSize, options: [.storageModeShared]) else {
            throw EngineError.bufferCreationFailed
        }
        noiseTextureBuffer = noiseBuf
        
        // ノイズデータの生成
        generatePerlinNoise()
    }
    
    private func setupTextures() throws {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = 1024  // メモリ使用量を削減
        textureDescriptor.height = 1024
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        textureDescriptor.storageMode = .shared
        
        guard let render = device.makeTexture(descriptor: textureDescriptor),
              let feedback = device.makeTexture(descriptor: textureDescriptor) else {
            throw EngineError.textureCreationFailed
        }
        
        renderTexture = render
        feedbackTexture = feedback
        
        // ノイズテクスチャ
        textureDescriptor.width = 512
        textureDescriptor.height = 512
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let noise = device.makeTexture(descriptor: textureDescriptor) else {
            throw EngineError.textureCreationFailed
        }
        noiseTexture = noise
        
        // ノイズテクスチャにデータを書き込む
        uploadNoiseTexture()
    }
    
    // MARK: - DNA Integration
    
    public func setHabitDNA(_ dna: HabitDNA) {
        self.habitDNA = dna
        
        // DNAからアートパラメータを生成
        let particleParams = dna.generateParticleParameters()
        let shaderParams = dna.generateShaderParameters()
        
        // パーティクル数の更新
        currentParticleCount = min(particleParams.count, maxParticles)
        
        // アートパラメータの更新
        artParameters = ArtGenerationParameters(
            particleCount: currentParticleCount,
            energy: particleParams.energy,
            colorPalette: shaderParams.colorGradient,
            waveforms: shaderParams.waveAmplitudes,
            chaosLevel: dna.chaosIndex,
            fractalDepth: shaderParams.fractalIterations,
            evolutionSpeed: dna.evolutionFactor
        )
        
        // パーティクルの初期化
        initializeParticles()
    }
    
    // MARK: - Particle System
    
    private func initializeParticles() {
        guard let dna = habitDNA else { return }
        
        let particles = particleBuffer.contents().bindMemory(
            to: Particle.self,
            capacity: currentParticleCount
        )
        
        // DNAシーケンスに基づくパーティクル生成
        guard !dna.sequence.isEmpty, currentParticleCount > 0 else { return }
        
        for i in 0..<currentParticleCount {
            let sequenceIndex = dna.sequence.isEmpty ? 0 : i % dna.sequence.count
            let nucleotide = dna.sequence.isEmpty ? HabitDNA.Nucleotide.adenine : dna.sequence[sequenceIndex]
            let angle = Float(i) * Float.pi * 2.0 / Float(max(1, currentParticleCount))
            let radius = Float(i) / Float(max(1, currentParticleCount)) * 500.0
            
            particles[i] = Particle(
                position: SIMD2<Float>(
                    cos(angle) * radius * nucleotide.weight,
                    sin(angle) * radius * nucleotide.weight
                ),
                velocity: SIMD2<Float>(
                    Float.random(in: -1...1) * artParameters.energy,
                    Float.random(in: -1...1) * artParameters.energy
                ),
                color: artParameters.colorPalette.isEmpty ? SIMD4<Float>(1, 1, 1, 1) : 
                       artParameters.colorPalette[Int(nucleotide.weight * 10) % max(1, artParameters.colorPalette.count)],
                size: nucleotide.weight * 2.0,
                life: 1.0,
                type: ParticleType(rawValue: i % 6)!
            )
        }
    }
    
    // MARK: - Rendering
    
    public func render(to drawable: CAMetalDrawable, viewportSize: CGSize) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        let renderPassDescriptor = createRenderPassDescriptor(for: drawable)
        
        // アップデートフェーズ
        updateParticles(deltaTime: 1.0/60.0)
        updateUniforms(viewportSize: viewportSize)
        
        // ジェネラティブアートコンピュート
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeGenerativeArt(encoder: computeEncoder)
            computeEncoder.endEncoding()
        }
        
        // レンダリングフェーズ
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            // Liquid Glass背景
            renderLiquidGlass(encoder: renderEncoder)
            
            // パーティクルシステム
            renderParticles(encoder: renderEncoder)
            
            // ポストプロセシング効果
            applyPostProcessing(encoder: renderEncoder)
            
            renderEncoder.endEncoding()
        }
        
        // フィードバックループ（アート進化用）
        if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
            blitEncoder.copy(from: renderTexture, to: feedbackTexture)
            blitEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        timeElapsed += 1.0/60.0
    }
    
    private func updateParticles(deltaTime: Float) {
        let particles = particleBuffer.contents().bindMemory(
            to: Particle.self,
            capacity: currentParticleCount
        )
        
        // GPUで並列処理する前の準備
        for i in 0..<currentParticleCount {
            var p = particles[i]
            
            // カオス的な動き
            let chaos = artParameters.chaosLevel
            p.velocity.x += sin(p.position.y * 0.01 + timeElapsed) * chaos
            p.velocity.y += cos(p.position.x * 0.01 + timeElapsed) * chaos
            
            // DNAに基づく引力・斥力
            if let dna = habitDNA {
                let attractorCount = min(dna.sequence.count, 10)
                for j in 0..<attractorCount {
                    let attractorAngle = Float(j) * Float.pi * 2.0 / Float(attractorCount)
                    let attractorPos = SIMD2<Float>(
                        cos(attractorAngle) * 300,
                        sin(attractorAngle) * 300
                    )
                    
                    let diff = attractorPos - p.position
                    let dist = length(diff)
                    if dist > 0.1 {
                        let force = dna.sequence[j].weight * 100.0 / (dist * dist)
                        p.velocity += normalize(diff) * force * deltaTime
                    }
                }
            }
            
            particles[i] = p
        }
    }
    
    private func updateUniforms(viewportSize: CGSize) {
        let uniforms = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        
        let waveforms = artParameters.waveforms + Array(repeating: Float(0), count: max(0, 8 - artParameters.waveforms.count))
        
        uniforms[0] = Uniforms(
            viewportSize: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
            time: timeElapsed,
            deltaTime: 1.0/60.0,
            chaosLevel: artParameters.chaosLevel,
            evolutionFactor: artParameters.evolutionSpeed,
            waveAmplitudes1: SIMD4<Float>(waveforms[0], waveforms[1], waveforms[2], waveforms[3]),
            waveAmplitudes2: SIMD4<Float>(waveforms[4], waveforms[5], waveforms[6], waveforms[7]),
            colorPalette: artParameters.colorPalette
        )
    }
    
    private func computeGenerativeArt(encoder: MTLComputeCommandEncoder) {
        // テクスチャがnilでないことを確認
        guard let noise = noiseTexture,
              let feedback = feedbackTexture,
              let render = renderTexture else {
            return
        }
        
        encoder.setComputePipelineState(generativeArtPipeline)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setTexture(noise, index: 0)
        encoder.setTexture(feedback, index: 1)
        encoder.setTexture(render, index: 2)
        
        // スレッドグループのサイズを安全に計算
        let threadsPerThreadgroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: max(1, (render.width + 15) / 16),
            height: max(1, (render.height + 15) / 16),
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    private func renderLiquidGlass(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(liquidGlassPipeline)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        if let noise = noiseTexture {
            encoder.setFragmentTexture(noise, index: 0)
        }
        if let feedback = feedbackTexture {
            encoder.setFragmentTexture(feedback, index: 1)
        }
        
        // フルスクリーンクワッド
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    private func renderParticles(encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(particlePipeline)
        encoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        encoder.drawPrimitives(
            type: .point,
            vertexStart: 0,
            vertexCount: currentParticleCount
        )
    }
    
    private func applyPostProcessing(encoder: MTLRenderCommandEncoder) {
        // グロー効果、ブルーム、色収差などのポストプロセシング
    }
    
    private func createRenderPassDescriptor(for drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = drawable.texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store
        return descriptor
    }
    
    // MARK: - Noise Generation
    
    private func uploadNoiseTexture() {
        guard let texture = noiseTexture else { return }
        
        let noiseData = noiseTextureBuffer.contents().bindMemory(to: Float.self, capacity: 512 * 512 * 4)
        
        texture.replace(
            region: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: 512, height: 512, depth: 1)
            ),
            mipmapLevel: 0,
            withBytes: noiseData,
            bytesPerRow: 512 * 4 * MemoryLayout<Float>.stride
        )
    }
    
    private func generatePerlinNoise() {
        let noiseData = noiseTextureBuffer.contents().bindMemory(to: Float.self, capacity: 512 * 512 * 4)
        
        for y in 0..<512 {
            for x in 0..<512 {
                let index = (y * 512 + x) * 4
                let fx = Float(x) / 512.0
                let fy = Float(y) / 512.0
                
                // 多層パーリンノイズ
                var noise: Float = 0
                var amplitude: Float = 1.0
                var frequency: Float = 1.0
                
                for _ in 0..<6 {
                    noise += perlinNoise2D(x: fx * frequency, y: fy * frequency) * amplitude
                    amplitude *= 0.5
                    frequency *= 2.0
                }
                
                noiseData[index] = noise
                noiseData[index + 1] = noise * 0.8
                noiseData[index + 2] = noise * 0.6
                noiseData[index + 3] = 1.0
            }
        }
    }
    
    private func perlinNoise2D(x: Float, y: Float) -> Float {
        // 簡易パーリンノイズ実装
        let xi = Int(floor(x))
        let yi = Int(floor(y))
        let xf = x - Float(xi)
        let yf = y - Float(yi)
        
        let u = fade(xf)
        let v = fade(yf)
        
        let aa = grad2D(hash: hash(xi, yi), x: xf, y: yf)
        let ab = grad2D(hash: hash(xi + 1, yi), x: xf - 1, y: yf)
        let ba = grad2D(hash: hash(xi, yi + 1), x: xf, y: yf - 1)
        let bb = grad2D(hash: hash(xi + 1, yi + 1), x: xf - 1, y: yf - 1)
        
        let x1 = lerp(aa, ab, u)
        let x2 = lerp(ba, bb, u)
        
        return lerp(x1, x2, v)
    }
    
    private func fade(_ t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + t * (b - a)
    }
    
    private func hash(_ x: Int, _ y: Int) -> Int {
        var h = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        return h
    }
    
    private func grad2D(hash: Int, x: Float, y: Float) -> Float {
        let h = hash & 3
        let u = h < 2 ? x : y
        let v = h < 2 ? y : x
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

// MARK: - Data Structures

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var type: ParticleType
}

enum ParticleType: Int {
    case flow = 0
    case burst = 1
    case orbit = 2
    case wave = 3
    case fractal = 4
    case quantum = 5
}

struct Uniforms {
    var viewportSize: SIMD2<Float>
    var time: Float
    var deltaTime: Float
    var chaosLevel: Float
    var evolutionFactor: Float
    var waveAmplitudes1: SIMD4<Float>
    var waveAmplitudes2: SIMD4<Float>
    var colorPalette: [SIMD4<Float>]
    
    init(viewportSize: SIMD2<Float>, time: Float, deltaTime: Float,
         chaosLevel: Float, evolutionFactor: Float,
         waveAmplitudes1: SIMD4<Float>, waveAmplitudes2: SIMD4<Float>,
         colorPalette: [SIMD4<Float>]) {
        self.viewportSize = viewportSize
        self.time = time
        self.deltaTime = deltaTime
        self.chaosLevel = chaosLevel
        self.evolutionFactor = evolutionFactor
        self.waveAmplitudes1 = waveAmplitudes1
        self.waveAmplitudes2 = waveAmplitudes2
        let paddingCount = colorPalette.count < 16 ? 16 - colorPalette.count : 0
        self.colorPalette = colorPalette + Array(repeating: SIMD4<Float>(1, 1, 1, 1), count: paddingCount)
    }
}

struct ArtGenerationParameters {
    let particleCount: Int
    let energy: Float
    let colorPalette: [SIMD4<Float>]
    let waveforms: [Float]
    let chaosLevel: Float
    let fractalDepth: Int
    let evolutionSpeed: Float
    
    static let `default` = ArtGenerationParameters(
        particleCount: 10000,
        energy: 1.0,
        colorPalette: [
            SIMD4<Float>(1, 0, 0, 1),
            SIMD4<Float>(0, 1, 0, 1),
            SIMD4<Float>(0, 0, 1, 1),
            SIMD4<Float>(1, 1, 0, 1)
        ],
        waveforms: [1, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125],
        chaosLevel: 0.5,
        fractalDepth: 5,
        evolutionSpeed: 1.0
    )
}

enum EngineError: Error {
    case deviceNotSupported
    case shaderNotFound
    case bufferCreationFailed
    case textureCreationFailed
}

// MARK: - Shader Source

struct VisualTrinityShaders {
    static let combinedShaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct Particle {
        float2 position;
        float2 velocity;
        float4 color;
        float size;
        float life;
        int type;
    };
    
    struct Uniforms {
        float2 viewportSize;
        float time;
        float deltaTime;
        float chaosLevel;
        float evolutionFactor;
        float4 waveAmplitudes1;  // 最初の4つの波形振幅
        float4 waveAmplitudes2;  // 次の4つの波形振幅
        float4 colorPalette[16];
    };
    
    // ヘルパー関数
    float3 hsv2rgb(float3 hsv) {
        float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
        float3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
        return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
    }
    
    // パーティクル頂点シェーダー
    vertex float4 particleVertex(uint vertexID [[vertex_id]],
                                constant Particle *particles [[buffer(0)]],
                                constant Uniforms *uniforms [[buffer(1)]]) {
        Particle p = particles[vertexID];
        
        float2 normalizedPos = p.position / uniforms->viewportSize * 2.0 - 1.0;
        normalizedPos.y *= -1.0;
        
        return float4(normalizedPos, 0.0, 1.0);
    }
    
    // パーティクルフラグメントシェーダー
    fragment float4 particleFragment(float4 position [[position]],
                                   constant Uniforms *uniforms [[buffer(0)]]) {
        float2 coord = position.xy / uniforms->viewportSize;
        
        // 距離に基づくグラデーション
        float dist = length(coord - 0.5);
        float glow = exp(-dist * 3.0);
        
        // 時間による色の変化
        float hue = uniforms->time * 0.1 + dist;
        float3 color = hsv2rgb(float3(hue, 0.8, 1.0));
        
        return float4(color * glow, glow);
    }
    
    // Liquid Glass頂点シェーダー
    vertex float4 liquidGlassVertex(uint vertexID [[vertex_id]]) {
        float2 positions[4] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2( 1.0,  1.0)
        };
        
        return float4(positions[vertexID], 0.0, 1.0);
    }
    
    // Liquid Glassフラグメントシェーダー
    fragment float4 liquidGlassFragment(float4 position [[position]],
                                      constant Uniforms *uniforms [[buffer(0)]],
                                      texture2d<float> noiseTexture [[texture(0)]],
                                      texture2d<float> feedbackTexture [[texture(1)]]) {
        float2 uv = position.xy / uniforms->viewportSize;
        
        // ノイズによる歪み
        float4 noise = noiseTexture.sample(sampler(filter::linear), uv + uniforms->time * 0.01);
        float2 distortion = (noise.xy - 0.5) * uniforms->chaosLevel * 0.1;
        
        // フィードバックループ
        float4 feedback = feedbackTexture.sample(sampler(filter::linear), uv + distortion);
        
        // 流体シミュレーション風の効果
        float wave = 0.0;
        for (int i = 0; i < 8; i++) {
            float freq = pow(2.0, float(i));
            float amp = i < 4 ? uniforms->waveAmplitudes1[i] : uniforms->waveAmplitudes2[i-4];
            wave += sin(uv.x * freq + uniforms->time) * amp;
            wave += cos(uv.y * freq + uniforms->time * 0.7) * amp;
        }
        
        float3 glassColor = hsv2rgb(float3(wave * 0.1 + uniforms->time * 0.05, 0.3, 0.9));
        
        return float4(mix(glassColor, feedback.rgb, 0.7), 1.0);
    }
    
    // ジェネラティブアートコンピュートシェーダー
    kernel void generativeArtCompute(uint2 gid [[thread_position_in_grid]],
                                   constant Particle *particles [[buffer(0)]],
                                   constant Uniforms *uniforms [[buffer(1)]],
                                   texture2d<float, access::read> noiseTexture [[texture(0)]],
                                   texture2d<float, access::read> feedbackTexture [[texture(1)]],
                                   texture2d<float, access::write> outputTexture [[texture(2)]]) {
        // 境界チェック
        if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
            return;
        }
        
        float2 uv = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());
        
        // フラクタルパターン生成
        float2 z = uv * 4.0 - 2.0;
        float2 c = float2(sin(uniforms->time * 0.1), cos(uniforms->time * 0.13));
        
        float iter = 0.0;
        for (int i = 0; i < 32; i++) {
            z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
            if (length(z) > 2.0) {
                iter = float(i) / 32.0;
                break;
            }
        }
        
        // 色の生成
        float3 color = hsv2rgb(float3(iter + uniforms->time * 0.1, 0.8, iter));
        
        // パーティクルの影響を追加
        float particleInfluence = 0.0;
        // ここでパーティクルの影響を計算（簡略化）
        
        outputTexture.write(float4(color, 1.0), gid);
    }
    """
}