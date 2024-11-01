import SwiftUI
import PencilKit

// Main data structure for recognized shapes
struct RecognizedElement: Identifiable {
    let id = UUID()
    var type: ElementType
    var bounds: CGRect
    var content: String
    var originalStrokes: [PKStroke]
}

// Types of elements that can be recognized
enum ElementType {
    case array
    case tree
    case linkedList
    case text
}

// Add this enum at the top level
enum DrawingTool {
    case pen
    case eraser
    case selector
}

// Add this extension at the top level of your file, near other structs/enums
extension PKStroke: @retroactive Equatable {}
extension PKStroke: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(renderBounds)
        hasher.combine(transform)
        hasher.combine(path.creationDate)
    }
    
    public static func == (lhs: PKStroke, rhs: PKStroke) -> Bool {
        return lhs.renderBounds == rhs.renderBounds &&
               lhs.transform == rhs.transform &&
               lhs.path.creationDate == rhs.path.creationDate
    }
}

// Main View
struct ContentView: View {
    @State private var canvas = PKCanvasView()
    @State private var recognizedElements: [RecognizedElement] = []
    @State private var selectedElement: RecognizedElement?
    @State private var isOptimizing = false
    @State private var currentTool: DrawingTool = .pen
    @State private var selectionPath: Path?
    @State private var undoManager: UndoManager?
    
    var body: some View {
        ZStack {
            CanvasView(canvas: $canvas, 
                      tool: currentTool,
                      undoManager: $undoManager)
                .gesture(
                    currentTool == .selector ?
                    DragGesture()
                        .onChanged { value in
                            // Create selection rectangle
                            selectionPath = Path { path in
                                let rect = CGRect(
                                    origin: value.startLocation,
                                    size: CGSize(
                                        width: value.location.x - value.startLocation.x,
                                        height: value.location.y - value.startLocation.y
                                    )
                                )
                                path.addRect(rect)
                            }
                        }
                        .onEnded { _ in
                            // Process selection
                            detectElements()
                            selectionPath = nil
                        }
                    : nil
                )
            
            // Show selection rectangle while dragging
            if let path = selectionPath {
                path.stroke(style: StrokeStyle(
                    lineWidth: 2,
                    dash: [5],
                    dashPhase: 5
                ))
                .foregroundColor(.blue)
            }
            
            // Overlay for recognized elements
            ForEach(recognizedElements) { element in
                RecognizedElementView(element: element)
                    .onTapGesture {
                        if currentTool == .selector {
                            selectedElement = element
                            isOptimizing = true
                        }
                    }
            }
            
            if isOptimizing {
                OptimizationPanel(element: $selectedElement, isShowing: $isOptimizing)
            }
            
            // Tool Selection Panel with Undo/Redo
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ToolButton(
                                icon: "arrow.uturn.backward",
                                isSelected: false,
                                action: { undoManager?.undo() }
                            )
                            .disabled(!(undoManager?.canUndo ?? false))
                            
                            ToolButton(
                                icon: "arrow.uturn.forward",
                                isSelected: false,
                                action: { undoManager?.redo() }
                            )
                            .disabled(!(undoManager?.canRedo ?? false))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(radius: 5)
                        )
                        
                        ToolSelectionPanel(currentTool: $currentTool)
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Optimize Selection") {
                    optimizeSelection()
                }
                .disabled(currentTool != .selector)
            }
        }
    }
    
    private func optimizeSelection() {
        let selectedStrokes = canvas.drawing.strokes.filter { stroke in
            if let selectionPath = selectionPath {
                return stroke.renderBounds.intersects(selectionPath.boundingRect)
            }
            return false
        }
        
        recognizeShape(from: selectedStrokes) { recognizedElement in
            if let element = recognizedElement {
                recognizedElements.append(element)
                // Remove the selected strokes from the canvas
                canvas.drawing.strokes.removeAll { stroke in
                    selectedStrokes.contains(stroke)
                }
            }
        }
    }
    
    private func recognizeShape(from strokes: [PKStroke], completion: @escaping (RecognizedElement?) -> Void) {
        // Here you would implement computer vision recognition
        // This is a placeholder that assumes it's an array
        let bounds = strokes.reduce(CGRect.null) { result, stroke in
            result.union(stroke.renderBounds)
        }
        
        let element = RecognizedElement(
            type: .array,
            bounds: bounds,
            content: "1,2,3", // This should come from text recognition
            originalStrokes: strokes
        )
        
        completion(element)
    }
    
    // Function to detect drawn elements
    private func detectElements() {
        // Implementation for shape recognition
        // This would use Vision framework or custom ML model
    }
}

// Canvas View
struct CanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var tool: DrawingTool
    @Binding var undoManager: UndoManager?
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.tool = PKInkingTool(.pen, color: .black, width: 1)
        canvas.drawingPolicy = .anyInput
        
        // Set up undo manager
        canvas.undoManager?.registerUndo(withTarget: canvas) { canvas in
            // Register undo action
            canvas.drawing = canvas.drawing
        }
        undoManager = canvas.undoManager
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        switch tool {
        case .pen:
            uiView.tool = PKInkingTool(.pen, color: .black, width: 1)
        case .eraser:
            uiView.tool = PKEraserTool(.vector)
        case .selector:
            // Disable drawing in selector mode
            uiView.tool = PKInkingTool(.pen, color: .clear, width: 0)
        }
    }
}

// View for optimized elements
struct RecognizedElementView: View {
    let element: RecognizedElement
    
    var body: some View {
        switch element.type {
        case .array:
            ArrayView(content: element.content)
        case .tree:
            TreeView(content: element.content)
        case .linkedList:
            LinkedListView(content: element.content)
        case .text:
            Text(element.content)
        }
    }
}

// Array View
struct ArrayView: View {
    let content: String
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(content.components(separatedBy: ","), id: \.self) { value in
                Rectangle()
                    .stroke(Color.black, lineWidth: 1)
                    .overlay(
                        Text(value.trimmingCharacters(in: .whitespaces))
                    )
                    .frame(width: 40, height: 40)
            }
        }
    }
}

// Optimization Panel
struct OptimizationPanel: View {
    @Binding var element: RecognizedElement?
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Text("Optimize Element")
                .font(.headline)
            
            Picker("Element Type", selection: .constant(0)) {
                Text("Array").tag(0)
                Text("Tree").tag(1)
                Text("Linked List").tag(2)
                Text("Text").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Content", text: .constant(""))
            
            HStack {
                Button("Apply") {
                    // Apply optimization
                    isShowing = false
                }
                
                Button("Cancel") {
                    isShowing = false
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}


struct TreeView: View {
    let content: String
    
    var body: some View {
        GeometryReader { geometry in
            let nodeSize: CGFloat = 40
            let levelHeight: CGFloat = 60
            let values = content.components(separatedBy: ",")
            
            ZStack {
                // Draw nodes
                ForEach(0..<values.count, id: \.self) { index in
                    let level = Int(log2(Double(index + 1)))
                    let nodesInLevel = pow(2.0, Double(level))
                    let horizontalSpacing = geometry.size.width / (nodesInLevel + 1)
                    let positionInLevel = Double(index + 1) - pow(2.0, Double(level)) + 1
                    
                    // Node
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(
                            Text(values[index].trimmingCharacters(in: .whitespaces))
                        )
                        .position(
                            x: horizontalSpacing * CGFloat(positionInLevel),
                            y: CGFloat(level) * levelHeight + nodeSize
                        )
                    
                    // Draw lines to children
                    if 2 * index + 1 < values.count {  // Left child
                        let childLevel = level + 1
                        let childNodesInLevel = pow(2.0, Double(childLevel))
                        let childSpacing = geometry.size.width / (childNodesInLevel + 1)
                        let childPosition = Double(2 * index + 1 + 1) - pow(2.0, Double(childLevel)) + 1
                        
                        Path { path in
                            path.move(to: CGPoint(
                                x: horizontalSpacing * CGFloat(positionInLevel),
                                y: CGFloat(level) * levelHeight + nodeSize
                            ))
                            path.addLine(to: CGPoint(
                                x: childSpacing * CGFloat(childPosition),
                                y: CGFloat(childLevel) * levelHeight + nodeSize
                            ))
                        }
                        .stroke(Color.black, lineWidth: 1)
                    }
                    
                    if 2 * index + 2 < values.count {  // Right child
                        let childLevel = level + 1
                        let childNodesInLevel = pow(2.0, Double(childLevel))
                        let childSpacing = geometry.size.width / (childNodesInLevel + 1)
                        let childPosition = Double(2 * index + 2 + 1) - pow(2.0, Double(childLevel)) + 1
                        
                        Path { path in
                            path.move(to: CGPoint(
                                x: horizontalSpacing * CGFloat(positionInLevel),
                                y: CGFloat(level) * levelHeight + nodeSize
                            ))
                            path.addLine(to: CGPoint(
                                x: childSpacing * CGFloat(childPosition),
                                y: CGFloat(childLevel) * levelHeight + nodeSize
                            ))
                        }
                        .stroke(Color.black, lineWidth: 1)
                    }
                }
            }
        }
        .frame(height: 300)  // Adjust based on your needs
    }
}

struct LinkedListView: View {
    let content: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(Array(content.components(separatedBy: ",").enumerated()), id: \.0) { index, value in
                    HStack(spacing: 0) {
                        // Node
                        Circle()
                            .stroke(Color.black, lineWidth: 1)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(value.trimmingCharacters(in: .whitespaces))
                            )
                        
                        // Arrow
                        if index < content.components(separatedBy: ",").count - 1 {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 20))
                                path.addLine(to: CGPoint(x: 20, y: 20))
                                // Arrow head
                                path.move(to: CGPoint(x: 15, y: 15))
                                path.addLine(to: CGPoint(x: 20, y: 20))
                                path.addLine(to: CGPoint(x: 15, y: 25))
                            }
                            .stroke(Color.black, lineWidth: 1)
                            .frame(width: 20, height: 40)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// Add this new view
struct ToolSelectionPanel: View {
    @Binding var currentTool: DrawingTool
    
    var body: some View {
        HStack(spacing: 16) {
            ToolButton(
                icon: "pencil",
                isSelected: currentTool == .pen,
                action: { currentTool = .pen }
            )
            
            ToolButton(
                icon: "eraser",
                isSelected: currentTool == .eraser,
                action: { currentTool = .eraser }
            )
            
            ToolButton(
                icon: "lasso",
                isSelected: currentTool == .selector,
                action: { currentTool = .selector }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 5)
        )
    }
}

// Add this helper view
struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .gray)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                )
        }
    }
}
