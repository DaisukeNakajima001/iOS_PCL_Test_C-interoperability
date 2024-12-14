//
//  PCLMesher.cpp
//  iOS_PCL_Test_C++ interoperability
//

#include "PCLMesher.hpp"
#include <iostream>
#include <vector>
#include <cstring>
#include <pcl/point_cloud.h>
#include <pcl/point_types.h>
#include <pcl/filters/statistical_outlier_removal.h>
#include <pcl/surface/poisson.h>
#include <pcl/features/normal_3d.h>
#include <pcl/PolygonMesh.h>
#include <pcl/conversions.h>
#include <pcl/search/kdtree.h>
#include <pcl/kdtree/kdtree_flann.h>
#include <pcl/io/obj_io.h>

extern "C" {
    const char* saveMeshAsOBJ(const simd_float3* pointCloud, int count, const char* filePath) {
        pcl::PointCloud<pcl::PointXYZ>::Ptr pclCloud(new pcl::PointCloud<pcl::PointXYZ>());

        // 点群をPCL形式に変換
        for (int i = 0; i < count; ++i) {
            pclCloud->push_back(pcl::PointXYZ(pointCloud[i].x, pointCloud[i].y, pointCloud[i].z));
        }

        // --- 統計外れ値除去 ---
        pcl::PointCloud<pcl::PointXYZ>::Ptr filteredCloud(new pcl::PointCloud<pcl::PointXYZ>());
        pcl::StatisticalOutlierRemoval<pcl::PointXYZ> sor;
        sor.setInputCloud(pclCloud);
        sor.setMeanK(20); // 近傍点数
        sor.setStddevMulThresh(1.0); // 標準偏差の乗数
        sor.filter(*filteredCloud);

        std::cout << "Filtered cloud size: " << filteredCloud->size() << " points." << std::endl;

        // --- 法線推定 ---
        pcl::PointCloud<pcl::Normal>::Ptr normals(new pcl::PointCloud<pcl::Normal>());
        pcl::NormalEstimation<pcl::PointXYZ, pcl::Normal> normalEstimation;
        normalEstimation.setInputCloud(filteredCloud);
        pcl::search::KdTree<pcl::PointXYZ>::Ptr tree(new pcl::search::KdTree<pcl::PointXYZ>());
        normalEstimation.setSearchMethod(tree);
        normalEstimation.setKSearch(10);
        normalEstimation.compute(*normals);

        // --- 法線付き点群作成 ---
        pcl::PointCloud<pcl::PointNormal>::Ptr cloudWithNormals(new pcl::PointCloud<pcl::PointNormal>());
        for (size_t i = 0; i < filteredCloud->size(); ++i) {
            pcl::PointNormal pointNormal;
            pointNormal.x = filteredCloud->points[i].x;
            pointNormal.y = filteredCloud->points[i].y;
            pointNormal.z = filteredCloud->points[i].z;
            pointNormal.normal_x = normals->points[i].normal_x;
            pointNormal.normal_y = normals->points[i].normal_y;
            pointNormal.normal_z = normals->points[i].normal_z;
            cloudWithNormals->push_back(pointNormal);
        }

        // --- ポアソン再構成 ---
        pcl::PolygonMesh mesh;
        pcl::Poisson<pcl::PointNormal> poisson;
        poisson.setInputCloud(cloudWithNormals);
        poisson.setDepth(8);
        poisson.reconstruct(mesh);

        // メッシュの生成に失敗した場合
        if (mesh.polygons.empty()) {
            std::cerr << "Mesh generation failed!" << std::endl;
            return nullptr;
        }

        // --- 頂点密度の計算 ---
        pcl::PointCloud<pcl::PointXYZ>::Ptr meshVertices(new pcl::PointCloud<pcl::PointXYZ>());
        pcl::fromPCLPointCloud2(mesh.cloud, *meshVertices);

        pcl::KdTreeFLANN<pcl::PointXYZ> kdtree;
        kdtree.setInputCloud(meshVertices);

        std::vector<float> densities(meshVertices->size(), 0.0f);
        const int kNeighbors = 10; // 近傍点の数
        for (size_t i = 0; i < meshVertices->size(); ++i) {
            std::vector<int> nearestIndices(kNeighbors);
            std::vector<float> nearestDistances(kNeighbors);
            kdtree.nearestKSearch(meshVertices->points[i], kNeighbors, nearestIndices, nearestDistances);

            // 密度計算: 距離の逆数を加算
            for (float distance : nearestDistances) {
                densities[i] += (distance > 0) ? 1.0f / distance : 0.0f;
            }
        }

        // --- 密度の閾値でフィルタリング ---
        float quantileThreshold = 0.10f; // 下位10%を削除
        std::vector<float> sortedDensities = densities;
        std::sort(sortedDensities.begin(), sortedDensities.end());
        float threshold = sortedDensities[static_cast<size_t>(quantileThreshold * sortedDensities.size())];

        // 削除する頂点をマーク
        std::vector<bool> verticesToRemove(meshVertices->size(), false);
        for (size_t i = 0; i < densities.size(); ++i) {
            if (densities[i] < threshold) {
                verticesToRemove[i] = true;
            }
        }

        // ポリゴンをフィルタリング
        std::vector<pcl::Vertices> filteredPolygons;
        for (const auto& polygon : mesh.polygons) {
            bool keepPolygon = true;
            for (const auto& vertexIndex : polygon.vertices) {
                if (verticesToRemove[vertexIndex]) {
                    keepPolygon = false;
                    break;
                }
            }
            if (keepPolygon) {
                filteredPolygons.push_back(polygon);
            }
        }

        // フィルタリング結果を反映
        mesh.polygons = filteredPolygons;
        
        // OBJ形式で保存
        if (pcl::io::saveOBJFile(filePath, mesh) < 0) {
            std::cerr << "Failed to save OBJ file!" << std::endl;
            return nullptr;
        }

        std::cout << "OBJ file saved at: " << filePath << std::endl;

        // パスを返すためのC文字列
        char* result = new char[strlen(filePath) + 1];
        std::strcpy(result, filePath);
        return result;
    }
}




