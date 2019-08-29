//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//

import SwiftUI

struct FlowLayout {
    let spacing: UIOffset
    let containerSize: CGSize
    
    init(containerSize: CGSize, spacing: UIOffset = UIOffset(horizontal: 10, vertical: 10)) {
        self.spacing = spacing
        self.containerSize = containerSize
    }
    
    var currentX = 0 as CGFloat
    var currentY = 0 as CGFloat
    var lineHeight = 0 as CGFloat
    
    mutating func add(element size: CGSize) -> CGRect {
        if currentX + size.width > containerSize.width {
            currentX = 0
            currentY += lineHeight + spacing.vertical
            lineHeight = 0
        }
        defer {
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing.horizontal
        }
        return CGRect(origin: CGPoint(x: currentX, y: currentY), size: size)
    }
    
    var size: CGSize {
        return CGSize(width: containerSize.width, height: currentY + lineHeight)
    }
}

func flowLayout<Elements>(for elements: Elements, containerSize: CGSize, sizes: [Elements.Element.ID: CGSize]) -> [(Elements.Element.ID, CGSize)] where Elements: RandomAccessCollection, Elements.Element: Identifiable {
    var state = FlowLayout(containerSize: containerSize)
    var result: [(Elements.Element.ID, CGSize)] = []
    for element in elements {
        let rect = state.add(element: sizes[element.id] ?? .zero)
        result.append((element.id, CGSize(width: rect.origin.x, height: rect.origin.y)))
    }
    return result
}

extension View {
    func offset(_ point: CGPoint) -> some View {
        return offset(x: point.x, y: point.y)
    }
}

struct CollectionView<Elements, Content>: View where Elements: RandomAccessCollection, Content: View, Elements.Element: Identifiable {
    var data: Elements
    var content: (Elements.Element) -> Content
    var didMove: (Elements.Index, Elements.Index) -> ()
    @State private var sizes: [Elements.Element.ID: CGSize] = [:]
    @State private var dragState: (id: Elements.Element.ID, translation: CGSize, location: CGPoint)? = nil
    
    private func dragOffset(for id: (Elements.Element.ID)) -> CGSize? {
        guard let state = dragState, state.id == id else { return nil }
        return state.translation
    }
    
    private func bodyHelper(containerSize: CGSize, offsets: [(Elements.Element.ID, CGSize)]) -> some View {
        var insertionPoint: (id: Elements.Element.ID, offset: CGSize)? {
            guard let ds = dragState else { return nil }
            for offset in offsets.reversed() {
                if  offset.1.width < ds.location.x && offset.1.height < ds.location.y {
                    return (id: offset.0, offset: offset.1)
                }
            }
            return nil
        }

        return ZStack(alignment: .topLeading) {
            ForEach(data) { element in
                PropagateSize(content: self.content(element), id: element.id)
                    .offset(offsets.first { element.id == $0.0 }?.1 ?? CGSize.zero)
                    .offset(self.dragOffset(for: element.id) ?? .zero)
                    .gesture(DragGesture().onChanged { value in
                        self.dragState = (element.id, value.translation, value.location)
                    }.onEnded { _ in
                        if let ds = self.dragState, let ip = insertionPoint,
                            let oldIdx = self.data.firstIndex(where: { $0.id == ds.id }),
                            let newIdx = self.data.firstIndex(where: { $0.id == ip.id }) {
                            self.didMove(oldIdx, newIdx)
                        }
                        self.dragState = nil
                    })
            }
            if insertionPoint != nil {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 10, height: 40)
                    .offset(insertionPoint!.offset)
            }
            Color.clear
                .frame(width: containerSize.width, height: containerSize.height)
                .fixedSize()
        }.onPreferenceChange(CollectionViewSizeKey.self) { value in
            withAnimation {
                self.sizes = value
            }
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            self.bodyHelper(containerSize: proxy.size, offsets: flowLayout(for: self.data, containerSize: proxy.size, sizes: self.sizes))
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
    @State var strings: [String] = (1...10).map { "Item \($0) " + String(repeating: "x", count: Int.random(in: 0...10)) }
    @State var dividerWidth: CGFloat = 100
    
    var body: some View {
        CollectionView(data: strings, content: {
            Text($0)
                .padding(10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }, didMove: { old, new in
            withAnimation {
                self.strings.move(fromOffsets: IndexSet(integer: old), toOffset: new)
            }
        }).padding(20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

