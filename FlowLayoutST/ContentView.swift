//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//

import SwiftUI

extension CGSize {
    init(_ point: CGPoint) {
        self.init(width: point.x, height: point.y)
    }
}

enum FlowAlignment {
    case leading
    case justify
}

func flowLayoutImpl<Id>(
    containerSize: CGSize,
    spacing: UIOffset = UIOffset(horizontal: 10, vertical: 10),
    sizes: [(Id, CGSize)],
    alignment: FlowAlignment) -> [(Id, CGRect)] {
    var current = CGPoint.zero
    var lineHeight = 0 as CGFloat

    var result: [(Id, CGRect)] = []
    var currentLine: [(Id, CGRect)] = []
    
    func startNewLine() {

        let spaceLeft = containerSize.width - current.x
        let numberOfSpaces = max(1, currentLine.count-1)
        
        current.x = 0
        current.y += lineHeight + spacing.vertical
        lineHeight = 0

        let spacePerLineItem = (spaceLeft / CGFloat(numberOfSpaces)).rounded()
 
        for i in currentLine.indices {
          var (id, rect) = currentLine[i]
            if alignment == .justify {
              rect.origin.x += CGFloat(i) * spacePerLineItem
          }
          result.append((id, rect))
        }
        currentLine = []
    }
    
    for (id, size) in sizes {
        if current.x + size.width > containerSize.width {
          startNewLine()
        }
        defer {
            lineHeight = max(lineHeight, size.height)
            current.x += size.width + spacing.horizontal
        }
        currentLine.append((id, CGRect(origin: current, size: size)))
    }
    startNewLine()
//    dump(result)
    return result
}

func flowLayout<Elements>(alignment: FlowAlignment = .justify) -> (_ elements: Elements, _ containerSize: CGSize, _ sizes: [Elements.Element.ID: CGSize]) -> [Elements.Element.ID: CGSize] where Elements: RandomAccessCollection, Elements.Element: Identifiable {
    return { elements, containerSize, sizes in
        let rects = flowLayoutImpl(containerSize: containerSize, sizes: elements.map { ($0.id, sizes[$0.id] ?? .zero) }, alignment: alignment)
        return Dictionary(uniqueKeysWithValues: rects.map { (id, rect) in (id, CGSize(rect.origin)) })
    }
}


func singleLineLayout<Elements>(for elements: Elements, containerSize: CGSize, sizes: [Elements.Element.ID: CGSize]) -> [Elements.Element.ID: CGSize] where Elements: RandomAccessCollection, Elements.Element: Identifiable {
    var result: [Elements.Element.ID: CGSize] = [:]
    var offset = CGSize.zero
    for element in elements {
        result[element.id] = offset
        let size = sizes[element.id] ?? CGSize.zero
        offset.width += size.width + 10
    }
    return result
}
    

struct CollectionView<Elements, Content>: View where Elements: RandomAccessCollection, Content: View, Elements.Element: Identifiable {
    var data: Elements
    var layout: (Elements, CGSize, [Elements.Element.ID: CGSize]) -> [Elements.Element.ID: CGSize]
    var content: (Elements.Element) -> Content
    @State private var sizes: [Elements.Element.ID: CGSize] = [:]
    
    private func bodyHelper(containerSize: CGSize, offsets: [Elements.Element.ID: CGSize]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(data) {
                PropagateSize(content: self.content($0), id: $0.id)
                    .offset(offsets[$0.id] ?? CGSize.zero)
                    .animation(.default)
            }
            Color.clear
                .frame(width: containerSize.width, height: containerSize.height)
                .fixedSize()
        }.onPreferenceChange(CollectionViewSizeKey.self) {
            self.sizes = $0
            
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            self.bodyHelper(containerSize: proxy.size, offsets: self.layout(self.data, proxy.size, self.sizes))
        }
    }
}

struct CollectionViewSizeKey<ID: Hashable>: PreferenceKey {
    typealias Value = [ID: CGSize]
    
    static var defaultValue: [ID: CGSize] { [:] }
    static func reduce(value: inout [ID:CGSize], nextValue: () -> [ID:CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct PropagateSize<V: View, ID: Hashable>: View {
    var content: V
    var id: ID
    var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: CollectionViewSizeKey<ID>.self, value: [self.id: proxy.size])
        })
    }
}

// todo hack

extension String: Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    let strings: [String] = (1...10).map { "Item \($0) " + String(repeating: "x", count: Int.random(in: 0...10)) }
    @State var dividerWidth: CGFloat = 100
    
    var body: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: dividerWidth)
                CollectionView(data: strings, layout: flowLayout(alignment: .justify)) {
                    Text($0).foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                }
            }
            Slider(value: $dividerWidth, in: 0...500)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

