//
//  test.hpp
//  iOS_PCL_Test_C++ interoperability
//
//  Created by user5773 on 11/29/24.
//

#ifndef PCLMesher_hpp
#define PCLMesher_hpp

#include "SwiftStdVectorWrapper.hpp"
#include <vector>
#include <simd/simd.h>
#include <string>

class PCLMesher {
public:
    std::string saveMeshAsOBJWrapper(const StdVectorSIMD3& pointCloud, const char* filePath); // ラッパー関数を宣言
    std::string saveMeshAsOBJ(const std::vector<simd_float3>& pointCloud, const std::string& filePath); // メッシュ生成のメイン処理
};

#endif /* PCLMesher_hpp */

