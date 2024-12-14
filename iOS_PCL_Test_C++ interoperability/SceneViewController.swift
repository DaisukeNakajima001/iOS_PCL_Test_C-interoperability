//
//  SceneViewController.swift
//  iOS_PCL_Test_C++ interoperability
//

import UIKit
import SceneKit
import ARKit
import SwiftUI
import Combine

class SceneViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    var sceneView: ARSCNView!
    var pointCloudNode = SCNNode()
    var meshNode = SCNNode()
    var depthEntities: [SCNNode] = []
    let horizontalPoints = 128
    let verticalPoints = 96
    let pointSize: CGFloat = 0.005
    
    @ObservedObject var arViewModel: ARViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    private let meshFilePath: String = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("mesh.obj").path
    }()
    
    // 初期化
    init(arViewModel: ARViewModel) {
        self.arViewModel = arViewModel
        super.init(nibName: nil, bundle: nil)
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // ビューのロード
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(sceneView)
        
        //arViewModel.setSceneView(sceneView)
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        
        sceneView.scene.rootNode.addChildNode(pointCloudNode)
        sceneView.scene.rootNode.addChildNode(meshNode)
        
        setupDepthVisualization()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .smoothedSceneDepth
        sceneView.session.run(configuration)
    }
    
    // バインディングの設定
    private func setupBindings() {
        arViewModel.$isMeshGenerated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isMesh in
                self?.updateNodeVisibility(isMeshGenerated: isMesh)
                if isMesh {
                    self?.displayMesh(at: self?.meshFilePath ?? "")
                }
            }
            .store(in: &cancellables)
    }
    
    // ノードの可視性を更新
    private func updateNodeVisibility(isMeshGenerated: Bool) {
        pointCloudNode.isHidden = isMeshGenerated
        meshNode.isHidden = !isMeshGenerated
    }
    
    // 点群のセットアップ
    private func setupDepthVisualization() {
        // 点群用ノードの作成
        let pointGeometry = SCNSphere(radius: pointSize)
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = UIColor.green
        pointGeometry.materials = [pointMaterial]
        
        for _ in 0..<(horizontalPoints * verticalPoints) {
            let pointNode = SCNNode(geometry: pointGeometry)
            pointNode.position = SCNVector3(0, 0, -1000) // 初期位置
            pointCloudNode.addChildNode(pointNode)
            depthEntities.append(pointNode)
        }
        
        // 初期状態
        pointCloudNode.isHidden = false
        meshNode.isHidden = true
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let smoothedDepth = frame.smoothedSceneDepth?.depthMap else { return }
        
        CVPixelBufferLockBaseAddress(smoothedDepth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(smoothedDepth, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(smoothedDepth, 0) else { return }
        let depthBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        let width = CVPixelBufferGetWidth(smoothedDepth)
        let height = CVPixelBufferGetHeight(smoothedDepth)
        
        let cameraIntrinsics = frame.camera.intrinsics
        
        let depthResolution = SIMD2<Float>(Float(width), Float(height))
        let capturedImageSize = frame.capturedImage.size
        
        let scaleRes = SIMD2<Float>(
            x: Float(capturedImageSize.width) / depthResolution.x,
            y: Float(capturedImageSize.height) / depthResolution.y
        )
        
        var adjustedIntrinsics = cameraIntrinsics
        adjustedIntrinsics[0][0] /= scaleRes.x
        adjustedIntrinsics[1][1] /= scaleRes.y
        adjustedIntrinsics[2][0] /= scaleRes.x
        adjustedIntrinsics[2][1] /= scaleRes.y
        
        let horizontalStep = Float(width) / Float(horizontalPoints)
        let verticalStep = Float(height) / Float(verticalPoints)
        let halfHorizontalStep = horizontalStep / 2
        let halfVerticalStep = verticalStep / 2
        
        for h in 0..<horizontalPoints {
            for v in 0..<verticalPoints {
                let x = Float(h) * horizontalStep + halfHorizontalStep
                let y = Float(v) * verticalStep + halfVerticalStep
                
                let depthMapPoint = SIMD2<Float>(x, y)
                let metricDepth = sampleDepth(depthBuffer, size: SIMD2<Int>(Int(width), Int(height)), at: SIMD2<Int>(Int(x), Int(y)))
                
                let worldPosition = computeWorldPosition(
                    depthMapPixelPoint: depthMapPoint,
                    depth: metricDepth,
                    cameraIntrinsics: adjustedIntrinsics,
                    viewMatrixInverted: frame.camera.viewMatrix(for: .landscapeRight).inverse
                )
                
                let entityIndex = v * horizontalPoints + h
                if entityIndex < depthEntities.count {
                    let node = depthEntities[entityIndex]
                    node.position = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z)
                }
            }
        }
        
        // 点群を ViewModel に渡す
        arViewModel.updatePointCloud(depthEntities: depthEntities)
    }
    
    private func sampleDepth(_ pointer: UnsafePointer<Float32>, size: SIMD2<Int>, at: SIMD2<Int>) -> Float {
        let index = at.y * size.x + at.x
        return pointer[index]
    }
    
    // ワールド座標を計算
    private func computeWorldPosition(depthMapPixelPoint: SIMD2<Float>, depth: Float, cameraIntrinsics: simd_float3x3, viewMatrixInverted: simd_float4x4) -> SIMD3<Float> {
        let xrw = ((depthMapPixelPoint.x - cameraIntrinsics[2][0]) * depth / cameraIntrinsics[0][0])
        let yrw = (depthMapPixelPoint.y - cameraIntrinsics[2][1]) * depth / cameraIntrinsics[1][1]
        
        let localPoint = SIMD3<Float>(xrw, -yrw, -depth)
        let worldPointHomogeneous = viewMatrixInverted * SIMD4<Float>(localPoint, 1.0)
        
        return SIMD3<Float>(worldPointHomogeneous.x, worldPointHomogeneous.y, worldPointHomogeneous.z)
    }
    
    // メッシュを表示
    func displayMesh(at path: String) {
        // 既存の子ノードを削除
        self.meshNode.childNodes.forEach { $0.removeFromParentNode() }

        guard FileManager.default.fileExists(atPath: path) else {
            print("Mesh file does not exist at path: \(path)")
            return
        }

        do {
            // メッシュファイルを読み込む
            let meshScene = try SCNScene(url: URL(fileURLWithPath: path), options: nil)
            
            // 読み込んだメッシュをSceneKitノードに追加
            for childNode in meshScene.rootNode.childNodes {
                let material = SCNMaterial()
                material.diffuse.contents = UIColor.green.withAlphaComponent(0.6) // 緑の半透明
                material.emission.contents = UIColor.green.withAlphaComponent(0.6) // 発光を追加
                material.isDoubleSided = true // 両面表示
                material.fillMode = .lines // ワイヤーフレーム表示
                material.lightingModel = .constant // 照明モデルを固定
                
                // 子ノードにマテリアルを設定
                childNode.geometry?.materials = [material]
                
                // メッシュノードに追加
                self.meshNode.addChildNode(childNode)
            }

            // SceneViewのルートノードにメッシュノードを追加
            self.sceneView.scene.rootNode.addChildNode(self.meshNode)
            print("Mesh displayed successfully.")
            
            // メッシュをワールド座標系に固定するためにアンカーを追加
            let anchor = ARAnchor(transform: matrix_identity_float4x4)
            self.sceneView.session.add(anchor: anchor)
            print("Anchor added for mesh.")
        } catch {
            print("Failed to load and display mesh: \(error)")
        }
    }

    
    // ARAnchorにメッシュを関連付ける
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // 作成したアンカーにメッシュノードを関連付ける
        if anchor.transform == matrix_identity_float4x4 {
            node.addChildNode(meshNode)
            print("MeshNode attached to anchor.")
        }
    }
}

struct SceneViewContainer: UIViewControllerRepresentable {
    let arViewModel: ARViewModel

    func makeUIViewController(context: Context) -> SceneViewController {
        return SceneViewController(arViewModel: arViewModel)
    }

    func updateUIViewController(_ uiViewController: SceneViewController, context: Context) {}
}

// CVPixelBufferのサイズ取得用の拡張
extension CVPixelBuffer {
    var size: CGSize {
        let width = CVPixelBufferGetWidthOfPlane(self, 0)
        let height = CVPixelBufferGetHeightOfPlane(self, 0)
        return CGSize(width: width, height: height)
    }
}
