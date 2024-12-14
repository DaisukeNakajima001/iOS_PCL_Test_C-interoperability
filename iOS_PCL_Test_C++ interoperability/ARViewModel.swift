//
//  ARViewModel.swift
//  iOS_PCL_Test_C++ interoperability
//

import Foundation
import SceneKit
import ARKit

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

        let resultPath = pointCloud.withUnsafeBufferPointer { buffer -> String? in
            objFilePath.withCString { pathPointer in
                if let objPath = saveMeshAsOBJ(buffer.baseAddress!, Int32(pointCloud.count), pathPointer) {
                    let filePath = String(cString: objPath)
                    print("OBJ file saved at: \(filePath)")
                    free(UnsafeMutablePointer(mutating: objPath)) // メモリ解放
                    return filePath // 保存成功時のパスを返す
                } else {
                    print("Failed to save OBJ file.")
                    return nil // 保存失敗時はnilを返す
                }
            }
        }

        if let path = resultPath {
            print("Mesh saved successfully at: \(path)")
            self.isMeshGenerated = true
        } else {
            print("Mesh saving failed.")
        }
    }
    
}

