//
//  SwiftStdVectorWrapper.hpp
//  iOS_PCL_Test_C++ interoperability
//
//  Created by user5773 on 12/18/24.
//

#ifndef SwiftStdVectorWrapper_hpp
#define SwiftStdVectorWrapper_hpp

#include <vector>
#include <simd/simd.h>

class StdVectorSIMD3 {
public:
    std::vector<simd_float3> vector;

    StdVectorSIMD3(const simd_float3* data, size_t count) {
        vector.assign(data, data + count);
    }
};

#endif /* SwiftStdVectorWrapper_hpp */
