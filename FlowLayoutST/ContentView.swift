//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//

import SwiftUI

struct CollectionView<Elements, Content>: View where Elements: RandomAccessCollection, Content: View, Elements.Element: Identifiable {
    var data: Elements
    var content: (Elements.Element) -> Content
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(data) {
                PropagateSize(content: self.content($0))
            }
        }.onPreferenceChange(CollectionViewSizeKey.self) {
            print($0)
        }
    }
}

struct CollectionViewSizeKey: PreferenceKey {
    typealias Value = [CGSize]
    
    static var defaultValue: [CGSize] { [] }
    static func reduce(value: inout [CGSize], nextValue: () -> [CGSize]) {
        value.append(contentsOf: nextValue())
    }
}

struct PropagateSize<V: View>: View {
    var content: V
    var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: CollectionViewSizeKey.self, value: [proxy.size])
        })
    }
}

// todo hack

extension String: Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    let strings: [String] = (1...10).map { "Item \($0) " + String(repeating: "x", count: Int.random(in: 0...10)) }
    
    var body: some View {
        CollectionView(data: strings) {
            Text($0)
                .padding(10)
                .background(Color.gray)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
