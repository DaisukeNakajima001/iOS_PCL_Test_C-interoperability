//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#ifndef iOS_PCL_Test_C++ interoperability-Bridging-Header_h
#define iOS_PCL_Test_C++ interoperability-Bridging-Header_h

# include "PCLMesher.hpp"

extern "C" {
    const char* saveMeshAsOBJ(const simd_float3* pointCloud, int count, const char* filePath);
}


#endif /* iOS_PCL_Test_C++ interoperability-Bridging-Header_h */


