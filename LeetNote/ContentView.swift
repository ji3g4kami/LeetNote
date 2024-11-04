import SwiftUI
import PencilKit

// Main data structure for recognized shapes
struct RecognizedElement: Identifiable {
    let id = UUID()
    var type: ElementType
    var bounds: CGRect
    var content: String
    var originalStrokes: [PKStroke]
    var position: CGPoint // Add this
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
    case hand  // New tool for moving strokes
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
    @State private var currentTool: DrawingTool = .pen
    @State private var selectionPath: Path?
    @State private var undoManager: UndoManager?
    @State private var isSelectionActive = false
    @State private var selectionBounds: CGRect = .zero
    @State private var showDataStructuresPanel = false
    @State private var previousDrawing: PKDrawing?
    @State private var initialDrawing = PKDrawing()
    @State private var draggedStrokes: [(stroke: PKStroke, initialTransform: CGAffineTransform)] = []
    @State private var dragStartLocation: CGPoint?
    @State private var originalDrawing: PKDrawing?
    @State private var previousLocation: CGPoint?
    @State private var dragOffset: CGPoint?
    @State private var strokeIdentifiers: [PKStroke: StrokeIdentifier] = [:]
    @State private var activeStrokeState: StrokeState?
    
    var dragGesture: some Gesture {
            DragGesture()
                .onChanged { value in
                    if currentTool == .selector {
                        handleSelectorDrag(value)
                    } else if currentTool == .hand {
                        handleHandDrag(value)
                    }
                }
                .onEnded { value in
                    if currentTool == .hand {
                        resetHandDrag()
                    } else if currentTool == .selector {
                        // Only keep selection if it's larger than a minimum size
                        let size = CGSize(
                            width: abs(value.location.x - value.startLocation.x),
                            height: abs(value.location.y - value.startLocation.y)
                        )
                        if size.width < 5 && size.height < 5 {
                            clearSelection()
                        }
                    }
                }
        }

        private func handleSelectorDrag(_ value: DragGesture.Value) {
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
            selectionBounds = rect
        }
        
        private func handleHandDrag(_ value: DragGesture.Value) {
            if dragStartLocation == nil {
                initializeHandDrag(at: value.startLocation)
            }
            
            if activeStrokeState != nil {
                updateDrawingWithTransform(at: value.location)
            }
        }
        
        private func resetHandDrag() {
            print("\n=== Ending Hand Drag ===")
            activeStrokeState = nil
            dragStartLocation = nil
            originalDrawing = nil
        }

        private func initializeHandDrag(at location: CGPoint) {
            print("\n=== Starting Hand Drag ===")
            dragStartLocation = location
            originalDrawing = canvas.drawing
            
            let touchArea = CGRect(
                x: location.x - 20,
                y: location.y - 20,
                width: 40,
                height: 40
            )
            print("Touch area:", touchArea)
            
            // Find stroke under touch point
            if let stroke = canvas.drawing.strokes.first(where: { $0.renderBounds.intersects(touchArea) }) {
                let strokeCenter = CGPoint(
                    x: stroke.renderBounds.midX,
                    y: stroke.renderBounds.midY
                )
                let offset = CGPoint(
                    x: location.x - strokeCenter.x,
                    y: location.y - strokeCenter.y
                )
                
                activeStrokeState = StrokeState(
                    stroke: stroke,
                    initialTransform: stroke.transform,
                    initialCenter: strokeCenter,
                    currentOffset: offset
                )
                
                print("Selected stroke center:", strokeCenter)
                print("Initial offset:", offset)
            }
        }
        
        private func updateDrawingWithTransform(at location: CGPoint) {
            guard let state = activeStrokeState else { return }
            
            print("\n=== Updating Stroke Position ===")
            var newDrawing = originalDrawing!
            
            // Remove the original stroke
            newDrawing.strokes.removeAll { $0.renderBounds == state.stroke.renderBounds }
            
            // Calculate new position
            let targetCenter = CGPoint(
                x: location.x - state.currentOffset.x,
                y: location.y - state.currentOffset.y
            )
            
            let dx = targetCenter.x - state.initialCenter.x
            let dy = targetCenter.y - state.initialCenter.y
            
            // Create transformed stroke
            var transformedStroke = state.stroke
            transformedStroke.transform = state.initialTransform.concatenating(
                CGAffineTransform(translationX: dx, y: dy)
            )
            
            newDrawing.strokes.append(transformedStroke)
            print("Moving stroke to:", targetCenter)
            
            canvas.drawing = newDrawing
        }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if currentTool == .selector {
                        clearSelection()
                    }
                }
            
            CanvasView(
                canvas: $canvas,
                tool: currentTool,
                undoManager: $undoManager
            )
            .gesture(currentTool == .pen || currentTool == .eraser ? nil : dragGesture)

            if let path = selectionPath, isSelectionActive {
                ZStack {
                    path.stroke(style: StrokeStyle(
                        lineWidth: 2,
                        dash: [5],
                        dashPhase: 5
                    ))
                    .foregroundColor(.blue)
                    
                    Button(action: {
                        copySelectedStrokes()
                        isSelectionActive = false
                        selectionPath = nil
                    }) {
                        Image(systemName: "doc.on.doc")
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
            
            ForEach(recognizedElements.indices, id: \.self) { index in
                RecognizedElementView(element: $recognizedElements[index])
                    .onTapGesture {
                        if currentTool == .selector {
                            selectedElement = recognizedElements[index]
                        }
                    }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ToolButton(
                                icon: "arrow.uturn.backward",
                                isSelected: false,
                                action: {
                                    canvas.undoManager?.undo()
                                }
                            )
                            
                            ToolButton(
                                icon: "arrow.uturn.forward",
                                isSelected: false,
                                action: {
                                    canvas.undoManager?.redo()
                                }
                            )
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(radius: 5)
                        )
                        
                        ToolSelectionPanel(
                            currentTool: $currentTool,
                            onToolChange: {
                                clearSelection()
                            }
                        )
                    }
                    .padding()
                }
            }
            
            VStack {
                DataStructuresPanel { type in
                    let element = RecognizedElement(
                        type: type == .array ? .array : .tree,
                        bounds: CGRect(x: 100, y: 100, width: 200, height: 50),
                        content: type == .array ? "" : "",
                        originalStrokes: [],
                        position: CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
                    )
                    recognizedElements.append(element)
                }
                .frame(width: 200)
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            initialDrawing = canvas.drawing
            canvas.becomeFirstResponder()
        }
    }
    
    // ... (keep all other methods like handleSelectorDrag, handleHandDrag, etc.)

    private func copySelectedStrokes() {
        print("\n=== Copying Elements ===")
        print("Selection bounds:", selectionBounds)
        
        // Copy strokes
        let selectedStrokes = canvas.drawing.strokes.filter { stroke in
            selectionBounds.contains(stroke.renderBounds)
        }
        print("Selected strokes to copy:", selectedStrokes.count)
        
        if !selectedStrokes.isEmpty {
            var newDrawing = canvas.drawing
            print("Original drawing strokes:", newDrawing.strokes.count)
            
            let offset = CGPoint(x: 20, y: 20)
            for stroke in selectedStrokes {
                var transformedStroke = stroke
                transformedStroke.transform = stroke.transform.concatenating(
                    CGAffineTransform(translationX: offset.x, y: offset.y)
                )
                
                let identifier = StrokeIdentifier(
                    bounds: transformedStroke.renderBounds,
                    creationDate: Date(),
                    id: UUID()
                )
                strokeIdentifiers[transformedStroke] = identifier
                
                newDrawing.strokes.append(transformedStroke)
                print("Created stroke copy with ID:", identifier.id)
            }
            
            canvas.drawing = newDrawing
        }
        
        // Modified selection logic for elements
        let normalizedSelectionBounds = CGRect(
            x: min(selectionBounds.minX, selectionBounds.maxX),
            y: min(selectionBounds.minY, selectionBounds.maxY),
            width: abs(selectionBounds.width),
            height: abs(selectionBounds.height)
        )
        
        let selectedElements = recognizedElements.filter { element in
            let elementFrame = CGRect(
                x: element.position.x - element.bounds.width/2,
                y: element.position.y - element.bounds.height/2,
                width: element.bounds.width,
                height: element.bounds.height
            )
            
            // Check if the element's center is within the selection bounds
            let elementCenter = CGPoint(x: element.position.x, y: element.position.y)
            let containsCenter = normalizedSelectionBounds.contains(elementCenter)
            
            print("Checking element at position:", element.position)
            print("Element frame:", elementFrame)
            print("Contains center:", containsCenter)
            print("Original content:", element.content)
            return containsCenter
        }
        
        print("Selected elements to copy:", selectedElements.count)
        
        for element in selectedElements {
            let offset = CGPoint(x: 20, y: 20)
            let newPosition = CGPoint(
                x: element.position.x + offset.x,
                y: element.position.y + offset.y
            )
            
            let newElement = RecognizedElement(
                type: element.type,
                bounds: element.bounds,
                content: element.content,
                originalStrokes: element.originalStrokes,
                position: newPosition
            )
            
            print("Created element copy at position:", newPosition)
            print("Copied content:", newElement.content)
            recognizedElements.append(newElement)
        }
    }
    
    private func clearSelection() {
        isSelectionActive = false
        selectionPath = nil
        selectionBounds = .zero
    }
}


// Canvas View
struct CanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var tool: DrawingTool
    @Binding var undoManager: UndoManager?
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen)
        canvas.delegate = context.coordinator
        canvas.becomeFirstResponder()
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        switch tool {
        case .pen:
            uiView.drawingPolicy = .anyInput
            uiView.tool = PKInkingTool(.pen)
        case .eraser:
            uiView.drawingPolicy = .anyInput
            uiView.tool = PKEraserTool(.vector)
        case .selector, .hand:
            // Use pencilOnly to restrict drawing while maintaining interaction
            uiView.drawingPolicy = .pencilOnly
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: CanvasView
        
        init(_ parent: CanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.undoManager = canvasView.undoManager
        }
    }
}


// View for optimized elements
struct RecognizedElementView: View {
    @Binding var element: RecognizedElement
    
    var body: some View {
        switch element.type {
        case .array:
            ArrayView(
                content: element.content,
                initialPosition: element.position,
                onContentChanged: { newContent in
                    element.content = newContent
                },
                element: $element
            )
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
    @State private var position: CGPoint
    @State private var values: [String]
    let onContentChanged: (String) -> Void
    @Binding var element: RecognizedElement
    
    init(content: String, initialPosition: CGPoint, onContentChanged: @escaping (String) -> Void, element: Binding<RecognizedElement>) {
        _position = State(initialValue: initialPosition)
        _values = State(initialValue: content.isEmpty ? [""] : content.components(separatedBy: ","))
        self.onContentChanged = onContentChanged
        _element = element
    }
    
    private func updateContent() {
        let newContent = values.joined(separator: ",")
        onContentChanged(newContent)
    }
    
    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                self.position = CGPoint(
                    x: value.location.x,
                    y: value.location.y
                )
                element.position = self.position
            }
        
        return HStack(spacing: 1) {
            // Front controls
            VStack(spacing: 4) {
                Button(action: {
                    if !values.isEmpty {
                        values.removeFirst()
                        updateContent()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                Button(action: {
                    values.insert("", at: 0)
                    updateContent()
                }) {
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
                                set: { newValue in
                                    values[index] = newValue
                                    updateContent()
                                }
                            ))
                            .multilineTextAlignment(.center)
                        )
                        .frame(width: 40, height: 40)
                }
            }
            .background(Color(UIColor.systemBackground))
            
            // Back controls
            VStack(spacing: 4) {
                Button(action: {
                    if !values.isEmpty {
                        values.removeLast()
                        updateContent()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                Button(action: {
                    values.append("")
                    updateContent()
                }) {
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
    var onToolChange: () -> Void  // Add this callback
    
    var body: some View {
        HStack(spacing: 16) {
            ToolButton(
                icon: "pencil",
                isSelected: currentTool == .pen,
                action: {
                    currentTool = .pen
                    onToolChange()
                }
            )
            
            ToolButton(
                icon: "eraser",
                isSelected: currentTool == .eraser,
                action: {
                    currentTool = .eraser
                    onToolChange()
                }
            )
            
            ToolButton(
                icon: "lasso",
                isSelected: currentTool == .selector,
                action: {
                    currentTool = .selector
                    onToolChange()
                }
            )
            
            ToolButton(
                icon: "hand.draw",
                isSelected: currentTool == .hand,
                action: {
                    currentTool = .hand
                    onToolChange()
                }
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

struct StrokeIdentifier: Hashable {
    let bounds: CGRect
    let creationDate: Date
    let id: UUID  // Add a unique identifier
}

struct StrokeState {
    let stroke: PKStroke
    let initialTransform: CGAffineTransform
    let initialCenter: CGPoint
    var currentOffset: CGPoint
}
