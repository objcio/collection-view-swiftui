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

struct Line<ID> {
    var items: [(ID, CGRect)]
    var height: CGFloat
}

func flowLayoutImpl<Id>(
    containerSize: CGSize,
    spacing: UIOffset = UIOffset(horizontal: 10, vertical: 10),
    sizes: [(Id, CGSize)],
    alignment: FlowAlignment) -> [Line<Id>] {
    var current = CGPoint.zero
    var lineHeight = 0 as CGFloat

    var result: [Line<Id>] = []
    var currentLine: [(Id, CGRect)] = []
    
    func startNewLine() {

        let spaceLeft = containerSize.width - current.x
        let numberOfSpaces = max(1, currentLine.count-1)
        let height = lineHeight
        
        current.x = 0
        current.y += lineHeight + spacing.vertical
        lineHeight = 0

        let spacePerLineItem = (spaceLeft / CGFloat(numberOfSpaces)).rounded()
 
        let theLine = (0..<currentLine.count).map { (i: Int) -> ((Id, CGRect)) in
          var (id, rect) = currentLine[i]
            if alignment == .justify {
              rect.origin.x += CGFloat(i) * spacePerLineItem
          }
          return (id, rect)
        }
        result.append(Line(items: theLine, height: height))
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

func flowLayout<Elements>(alignment: FlowAlignment = .justify) -> (_ elements: Elements, _ containerSize: CGSize, _ sizes: [(Elements.Element.ID, CGSize)]) -> [Line<Elements.Element.ID>] where Elements: RandomAccessCollection, Elements.Element: Identifiable {
    return { elements, containerSize, sizes in
        let rects = flowLayoutImpl(containerSize: containerSize, sizes: sizes, alignment: alignment)
        return rects
    }
}

struct CollectionView<Elements, Content>: View where Elements: RandomAccessCollection, Content: View, Elements.Element: Identifiable {
    var data: Elements
    var layout: Layout
    typealias Layout = (Elements, CGSize, [(Elements.Element.ID, CGSize)]) -> [Line<Elements.Element.ID>]
    typealias Reorder = (_ from: Elements.Index, _ before: Elements.Index) -> ()
    var content: (Elements.Element) -> Content
    private var _onReorder: Reorder = { _, _ in () }
    @State private var sizes: [(Elements.Element.ID, CGSize)] = []
    @State private var selectedIndex: Elements.Element.ID? = nil
    @State private var dragTranslation: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero
    
    init(data: Elements, layout: @escaping Layout, onReorder: Reorder? = nil, content: @escaping (Elements.Element) -> Content) {
        self.data = data
        self.layout = layout
        self.content = content
        if let o = onReorder { self._onReorder = o}
    }

    private func dragCursorPosition(lines: [Line<Elements.Element.ID>], position: CGPoint) -> (position: CGSize, id: Elements.Element.ID)? {
        var lineY: CGFloat = 0
        for line in lines {
            lineY += line.height
            print(position.y, line.height)
            guard position.y < lineY else { continue }
            for item in line.items {
                let rect = item.1
                if position.x < rect.maxX {
                    return (CGSize(width: rect.minX, height: rect.minY), item.0)
                }
            }
        }
        return nil
    }
    
    private func bodyHelper(containerSize: CGSize, lines: [Line<Elements.Element.ID>]) -> some View {
        let cursorPos = dragCursorPosition(lines: lines, position: dragLocation)
        let offsets = Dictionary<Elements.Element.ID, CGSize>(uniqueKeysWithValues: lines.flatMap { line in
            line.items.map { ($0.0, CGSize($0.1.origin)) }
        })
        return ZStack(alignment: .topLeading) {
            ForEach(data) { el in
                PropagateSize(content: self.content(el), id: el.id)
                    .offset(offsets[el.id] ?? .zero)
                    .offset(el.id == self.selectedIndex ? self.dragTranslation : .zero)
                    .opacity(el.id == self.selectedIndex ? 0.8 : 1)
                    .animation(.default)
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .named("Container"))
                            .onChanged( { value in
                                self.selectedIndex = el.id
                                self.dragTranslation = value.translation
                                self.dragLocation = value.location
                            }).onEnded({ _ in
                                if let old = self.data.firstIndex(where: { $0.id == self.selectedIndex }), let newId = cursorPos?.id, let new = self.data.firstIndex(where: { $0.id == newId }) {
                                    self._onReorder(old, new)
                                }
                                self.selectedIndex = nil
                                self.dragLocation = .zero
                            })
                        )
            }
//            if selectedIndex != nil {
            if selectedIndex != nil && cursorPos != nil {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 5, height: 20)
                    .offset(cursorPos!.position)
                    .zIndex(100000)
            }
//            Rectangle()
//                .fill(Color.green)
//                .frame(width: 5, height: 20)
//                .offset(x: dragLocation.x, y: dragLocation.y)
//                .offset(x: -10, y: -10)
//                .zIndex(100000)
////            }
            Color.clear
                .frame(width: containerSize.width, height: containerSize.height)
                .fixedSize()
        }
        .coordinateSpace(name: "Container")
        .onPreferenceChange(CollectionViewSizeKey.self) {
            self.sizes = $0.map { $0.tuple }
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            self.bodyHelper(containerSize: proxy.size, lines: self.layout(self.data, proxy.size, self.sizes))
        }
    }
}

struct Pair<A,B> {
    let l: A
    let r: B
    init(_ l: A, _ r: B) {
        self.l = l
        self.r = r
    }
    
    var tuple: (A,B) { (l,r) }
}

extension Pair: Equatable where A: Equatable, B: Equatable { }



struct CollectionViewSizeKey<ID: Hashable>: PreferenceKey {
    typealias Value = [Pair<ID, CGSize>]
    
    static var defaultValue: Value { [] }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.append(contentsOf: nextValue())
    }
}

struct PropagateSize<V: View, ID: Hashable>: View {
    var content: V
    var id: ID
    var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: CollectionViewSizeKey<ID>.self, value: [Pair(self.id, proxy.size)])
        })
    }
}

// todo hack

extension String: Identifiable {
    public var id: String { self }
}

struct ContentView: View {
    @State var strings: [String] = (1...10).map { "Item \($0) " + (Bool.random() ? "\n" : "")  + String(repeating: "x", count: Int.random(in: 0...10)) }
    @State var dividerWidth: CGFloat = 100
    
    var body: some View {
        VStack {
            HStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: dividerWidth)
                CollectionView(data: strings, layout: flowLayout(alignment: .justify), onReorder: { old, new in
                    self.strings.move(fromOffsets: IndexSet(integer: old), toOffset: new)
                }) {
                    Text($0).foregroundColor(.white)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                }.padding(20)
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

