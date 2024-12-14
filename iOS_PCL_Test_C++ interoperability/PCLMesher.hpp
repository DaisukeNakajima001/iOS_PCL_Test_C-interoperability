//
//  test.hpp
//  iOS_PCL_Test_C++ interoperability
//
//  Created by user5773 on 11/29/24.
//

#ifndef PCLMesher_hpp
#define PCLMesher_hpp

#include <vector>
#include <simd/simd.h>

extern "C" {
    const char* saveMeshAsOBJ(const simd_float3* pointCloud, int count, const char* filePath);
    const char* saveMeshAsPLY(const simd_float3* pointCloud, int count, const char* filePath);
}

#endif /* PCLMesher_hpp */

