//
//  ContentView.swift
//  iOS_PCL_Test_C++ interoperability
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    
    var body: some View {
        ZStack {
            SceneViewContainer(arViewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Button(arViewModel.isMeshGenerated ? "Point Cloud" : "Mesh") {
                    if arViewModel.isMeshGenerated {
                        // 点群表示に切り替え
                        arViewModel.isMeshGenerated = false
                    } else {
                        // メッシュ生成と表示
                        arViewModel.performReconstruction()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#Preview {
    ContentView()
}

