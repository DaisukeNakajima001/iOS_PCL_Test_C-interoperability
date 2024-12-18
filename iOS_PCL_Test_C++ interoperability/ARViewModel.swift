//
//  ARViewModel.swift
//  iOS_PCL_Test_C++ interoperability
//

import Foundation
import SceneKit
import ARKit
import SwiftUI

class ARViewModel: ObservableObject {
    private var sceneView: ARSCNView?
    
    // メッシュ生成フラグ
    @Published var isMeshGenerated: Bool = false
    
    // ファイル保存用のパス
    let fm = FileManager.default
    let documentsPath: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    
    // 点群データ
    private var depthEntities: [SCNNode] = []
    private let horizontalPoints = 128
    private let verticalPoints = 96
    
    // SceneView を設定
    func setSceneView(_ view: ARSCNView) {
        self.sceneView = view
    }

    // 点群の更新を処理
    func updatePointCloud(depthEntities: [SCNNode]) {
        self.depthEntities = depthEntities
    }
    
    // 点群データの取得
    func getPointCloud() -> [SIMD3<Float>] {
        return depthEntities.compactMap { node in
            let position = node.position
            return SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
        }
    }
    
    // メッシュ生成
    func performReconstruction() {
        let pointCloud = getPointCloud()
        guard !pointCloud.isEmpty else {
                print("Point cloud is empty or invalid")
                return
            }

        let objFilePath = documentsPath + "/mesh.obj"
        // Swift 配列を C++ の std::vector に変換
        pointCloud.withUnsafeBufferPointer { bufferPointer in
            let cppPointCloud = StdVectorSIMD3(bufferPointer.baseAddress, bufferPointer.count)

            // Swift の String を C の const char* に変換
            objFilePath.withCString { filePathCString in
                var mesher = PCLMesher() // C++ クラスのインスタンス作成
                let resultPath = mesher.saveMeshAsOBJWrapper(cppPointCloud, filePathCString) // メソッドを呼び出す

                if resultPath.isEmpty {
                    print("Mesh saving failed.")
                } else {
                    print("Mesh saved successfully at: \(resultPath)")
                    self.isMeshGenerated = true
                }
            }
        }
    }
    
}

