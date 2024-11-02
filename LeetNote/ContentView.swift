import SwiftUI
import PencilKit
import Vision

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

// Add this new enum
enum DataStructureType {
    case array
    case tree
    case linkedList
}

// Add this new panel view
struct DataStructuresPanel: View {
    var onSelect: (DataStructureType) -> Void
    
    var body: some View {
        VStack {
            Text("Data Structures")
                .font(.headline)
                .padding(.bottom)
            
            Button(action: { onSelect(.array) }) {
                HStack {
                    Image(systemName: "rectangle.split.3.horizontal")
                    Text("Array")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: { onSelect(.tree) }) {
                HStack {
                    Image(systemName: "triangle")
                    Text("Tree")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
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
    @State private var isSelectionActive = false
    @State private var selectionBounds: CGRect = .zero
    @State private var showDataStructuresPanel = false
    
    var body: some View {
        ZStack {
            CanvasView(canvas: $canvas, 
                      tool: currentTool,
                      undoManager: $undoManager)
                .gesture(
                    currentTool == .selector ?
                    DragGesture()
                        .onChanged { value in
                            isSelectionActive = true
                            let rect = CGRect(
                                origin: value.startLocation,
                                size: CGSize(
                                    width: value.location.x - value.startLocation.x,
                                    height: value.location.y - value.startLocation.y
                                )
                            )
                            selectionPath = Path { path in
                                path.addRect(rect)
                            }
                            // Update bounds for button positioning
                            selectionBounds = rect
                        }
                    : nil
                )
            
            // Selection path view with floating button
            if let path = selectionPath, isSelectionActive {
                ZStack {
                    // Selection rectangle
                    path.stroke(style: StrokeStyle(
                        lineWidth: 2,
                        dash: [5],
                        dashPhase: 5
                    ))
                    .foregroundColor(.blue)
                    
                    // Floating optimize button
                    Button(action: {
                        optimizeSelection()
                        isSelectionActive = false
                        selectionPath = nil
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .position(
                        x: selectionBounds.maxX + 30,
                        y: selectionBounds.minY - 30
                    )
                }
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
            
            // Data Structures Panel
            VStack {
                DataStructuresPanel { type in
                    // Create new data structure
                    let element = RecognizedElement(
                        type: type == .array ? .array : .tree,
                        bounds: CGRect(x: 100, y: 100, width: 200, height: 50),
                        content: "",
                        originalStrokes: []
                    )
                    recognizedElements.append(element)
                }
                .frame(width: 200)
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func optimizeSelection() {
        guard let selectionPath = selectionPath else { return }
        
        let selectedStrokes = canvas.drawing.strokes.filter { stroke in
            stroke.renderBounds.intersects(selectionPath.boundingRect)
        }
        
        // Create an image from the selected strokes
        let renderer = UIGraphicsImageRenderer(bounds: selectionPath.boundingRect)
        let strokeImage = renderer.image { context in
            let drawing = PKDrawing(strokes: selectedStrokes)
            drawing.image(from: selectionPath.boundingRect, scale: 1.0).draw(in: selectionPath.boundingRect)
        }
        
        // Perform shape recognition using Vision
        recognizeShape(from: strokeImage) { recognizedType in
            let bounds = selectionPath.boundingRect
            let element = RecognizedElement(
                type: recognizedType,
                bounds: bounds,
                content: "1,2,3", // This should come from text recognition
                originalStrokes: selectedStrokes
            )
            
            recognizedElements.append(element)
            
            // Remove the selected strokes from the canvas
            canvas.drawing.strokes.removeAll { stroke in
                selectedStrokes.contains(stroke)
            }
        }
    }
    
    private func recognizeShape(from image: UIImage, completion: @escaping (ElementType) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.array) // Default fallback
            return
        }
        
        // Configure the request
        let request = VNDetectRectanglesRequest { request, error in
            guard let results = request.results as? [VNRectangleObservation] else {
                completion(.array) // Default fallback
                return
            }
            
            // Analyze the detected rectangles
            if results.count > 1 {
                // Multiple rectangles might indicate an array
                completion(.array)
            } else if results.count == 1 {
                // Single rectangle might be a tree node
                completion(.tree)
            } else {
                // Default to array if unsure
                completion(.array)
            }
        }
        
        // Configure request parameters
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = 45
        request.minimumSize = 0.2
        request.maximumObservations = 10
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
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
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
    @State private var values: [String]
    
    init(content: String) {
        _values = State(initialValue: content.components(separatedBy: ","))
    }
    
    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                self.position = CGPoint(
                    x: value.location.x,
                    y: value.location.y
                )
            }
        
        return HStack(spacing: 1) {
            // Front controls
            VStack(spacing: 4) {
                // Delete button
                Button(action: {
                    if !values.isEmpty {
                        values.removeFirst()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                // Add button
                Button(action: { values.insert("", at: 0) }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .offset(x: 10)
            .zIndex(1)
            
            // Array cells
            HStack(spacing: 1) {
                ForEach(values.indices, id: \.self) { index in
                    Rectangle()
                        .stroke(Color.black, lineWidth: 1)
                        .overlay(
                            TextField("", text: Binding(
                                get: { values[index] },
                                set: { values[index] = $0 }
                            ))
                            .multilineTextAlignment(.center)
                        )
                        .frame(width: 40, height: 40)
                }
            }
            
            // Back controls
            VStack(spacing: 4) {
                // Delete button
                Button(action: {
                    if !values.isEmpty {
                        values.removeLast()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                // Add button
                Button(action: { values.append("") }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .offset(x: -10)
            .zIndex(1)
        }
        .position(x: position.x, y: position.y)
        .gesture(dragGesture)
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
