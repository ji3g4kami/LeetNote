import SwiftUI

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var tool: DrawingTool
    var text: String?
}

enum GridOrientation {
    case rowByCol
    case colByRow
}

enum DrawingTool: CaseIterable {
    case pen, eraser, rectangle, circle, arrow, text, selection, hand, deque, grid, linkedList

    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .eraser: return "eraser"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .arrow: return "arrow.right"
        case .text: return "text.cursor"
        case .selection: return "lasso"
        case .hand: return "hand.draw"
        case .deque: return "rectangle.split.3x1"
        case .grid: return "rectangle.split.3x3"
        case .linkedList: return "list.bullet"
        }
    }
}

// Add this new class to store deque data
class DSViewData<T>: ObservableObject, Identifiable {
    let id: UUID
    @Published var position: CGPoint
    @Published var values: T
    
    init(id: UUID = UUID(), position: CGPoint, initialValues: T) {
        self.id = id
        self.position = position
        self.values = initialValues
    }
}

struct ContentView: View {
    @State private var lines: [Line] = []
    @State private var currentLine: Line?
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .black
    @State private var lineWidth: CGFloat = 3
    @State private var currentText = ""
    @State private var undoStack: [[Line]] = []
    @State private var redoStack: [[Line]] = []
    @State private var selectedShapeIndex: Int?
    @State private var selectedElements: Set<Int> = []
    @State private var dragOffset: CGSize = .zero
    @State private var textPosition: CGPoint?
    @State private var isShowingTextField = false
    @State private var isShowingDequeAlert = false
    @State private var isShowingLinkedListAlert = false
    @State private var dequeInitialValues = ""
    @State private var linkedListInitialValues = ""
    @State private var pendingDequePosition: CGPoint?
    @State private var pendingLinkedListPosition: CGPoint?
    @State private var isShowingTextAlert = false
    @State private var isShowingGridAlert = false
    @State private var gridArrayInput = ""
    @State private var pendingGridPosition: CGPoint?
    @State private var isDraggingOverBin = false
    @State private var binAnimation = false
    @State private var showDataStructuresOnTop = true
    @State private var gridOrientation: GridOrientation = .rowByCol
    @State private var deques: [DSViewData<[String]>] = []
    @State private var grids: [DSViewData<String>] = []
    @State private var linkedLists: [DSViewData<[String]>] = []
    
    var body: some View {
        VStack {
            // Replace toolbar with new component
            ToolbarView(
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                currentText: $currentText,
                selectedElements: $selectedElements,
                showDataStructuresOnTop: $showDataStructuresOnTop,
                lines: $lines,
                undoAction: undo,
                redoAction: redo,
                copyAction: copySelected,
                clearAction: {
                    undoStack.append(lines)
                    lines.removeAll()
                    redoStack.removeAll()
                    selectedElements.removeAll()
                    currentText = ""
                    deques.removeAll()
                    grids.removeAll()
                    linkedLists.removeAll()
                },
                canUndo: !undoStack.isEmpty,
                canRedo: !redoStack.isEmpty,
                saveCurrentText: saveCurrentText
            )
            
            // Canvas
            ZStack {
                if !showDataStructuresOnTop {
                    // Data Structures Layer
                    dataStructuresLayer
                }
                
                // Canvas Layer
                canvasLayer
                
                if showDataStructuresOnTop {
                    // Data Structures Layer
                    dataStructuresLayer
                }
                
                // Bin Layer (always on top)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: isDraggingOverBin ? "trash.circle.fill" : "trash.circle")
                            .font(.system(size: 40))
                            .foregroundColor(isDraggingOverBin ? .red : .gray)
                            .padding()
                            .scaleEffect(binAnimation ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: binAnimation)
                    }
                }
            }
            .background(Color.white)
            .border(Color.gray)

            // Overlay TextField for text input
            if isShowingTextField, let position = textPosition {
                TextField("Enter text", text: $currentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                    .position(x: position.x, y: position.y)
                    .onSubmit {
                        if !currentText.isEmpty {
                            let newLine = Line(
                                points: [position],
                                color: selectedColor,
                                lineWidth: lineWidth,
                                tool: .text,
                                text: currentText
                            )
                            undoStack.append(lines)
                            lines.append(newLine)
                            redoStack.removeAll()
                        }
                        isShowingTextField = false
                        currentText = ""
                    }
                    .onAppear {
                        // Focus the TextField when it appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder),
                                                         to: nil,
                                                         from: nil,
                                                         for: nil)
                        }
                    }
            }
            
            // Show text field when shape is selected
            if let index = selectedShapeIndex {
                HStack {
                    TextField("Enter text", text: $currentText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: currentText) { oldValue, newValue in
                            var updatedLine = lines[index]
                            updatedLine.text = newValue
                            lines[index] = updatedLine
                        }
                    
                    Button("Done") {
                        selectedShapeIndex = nil
                        currentText = ""
                    }
                }
                .padding()
            }
        }
        .overlay(
            AlertsOverlay(
                isShowingDequeAlert: $isShowingDequeAlert,
                isShowingTextAlert: $isShowingTextAlert,
                isShowingGridAlert: $isShowingGridAlert,
                isShowingLinkedListAlert: $isShowingLinkedListAlert,
                dequeInitialValues: $dequeInitialValues,
                linkedListInitialValues: $linkedListInitialValues,
                currentText: $currentText,
                gridArrayInput: $gridArrayInput,
                pendingDequePosition: $pendingDequePosition,
                pendingGridPosition: $pendingGridPosition,
                pendingLinkedListPosition: $pendingLinkedListPosition,
                textPosition: $textPosition,
                gridOrientation: $gridOrientation,
                lines: $lines,
                undoStack: $undoStack,
                redoStack: $redoStack,
                deques: $deques,
                grids: $grids,
                linkedLists: $linkedLists
            )
        )
        .onChange(of: deques.count) { _, _ in
            selectedTool = .hand
        }
        .onChange(of: grids.count) { _, _ in
            selectedTool = .hand
        }
        .onChange(of: linkedLists.count) { _, _ in
            selectedTool = .hand
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value) {
        if selectedTool == .hand && !selectedElements.isEmpty {
            // Handle dragging selected elements with hand tool
            dragOffset = value.translation
        } else {
            let point = value.location
            if currentLine == nil {
                currentLine = Line(points: [point], color: selectedColor, lineWidth: lineWidth, tool: selectedTool)
            } else {
                currentLine?.points.append(point)
            }
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        if selectedTool == .hand && !selectedElements.isEmpty {
            // Apply the drag to selected elements
            applyDragToSelected()
            dragOffset = .zero
        } else {
            if let line = currentLine {
                undoStack.append(lines)
                redoStack.removeAll()
                lines.append(line)
            }
            currentLine = nil
        }
    }
    
    private func handleTap(at location: CGPoint) {
        if selectedTool == .selection || selectedTool == .hand {
            var tappedSelectedElement = false
            
            // Check if tap is inside any selected element
            for index in selectedElements {
                let line = lines[index]
                let bounds = line.points.reduce(CGRect.null) { rect, point in
                    rect.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
                }
                // Add some padding to make selection easier
                let selectionRect = bounds.insetBy(dx: -10, dy: -10)
                
                if selectionRect.contains(location) {
                    tappedSelectedElement = true
                    break
                }
            }
            
            // If we tapped outside, clear selection and check for new elements to select
            if !tappedSelectedElement {
                selectedElements.removeAll()
                
                // Only try to select new elements if using selection tool
                if selectedTool == .selection {
                    // Try to select new element at tap location
                    for (index, line) in lines.enumerated().reversed() {
                        let bounds = line.points.reduce(CGRect.null) { rect, point in
                            rect.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
                        }
                        let selectionRect = bounds.insetBy(dx: -10, dy: -10)
                        
                        if selectionRect.contains(location) {
                            selectedElements.insert(index)
                            return
                        }
                    }
                }
            }
            return
        }
        
        // Original shape selection code for rectangle/circle text
        for (index, line) in lines.enumerated().reversed() {
            if line.tool == .rectangle || line.tool == .circle {
                if let first = line.points.first, let last = line.points.last {
                    let rect = CGRect(
                        x: min(first.x, last.x),
                        y: min(first.y, last.y),
                        width: abs(last.x - first.x),
                        height: abs(last.y - first.y)
                    )
                    
                    if rect.contains(location) {
                        selectedShapeIndex = index
                        currentText = line.text ?? ""
                        return
                    }
                }
            }
        }
        
        selectedShapeIndex = nil
        currentText = ""
    }
    
    private func drawElement(context: GraphicsContext, line: Line, isSelected: Bool) {
        // Draw the regular element first
        switch line.tool {
        case .pen:
            var path = Path()
            path.addLines(line.points)
            context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
            
        case .eraser:
            var path = Path()
            path.addLines(line.points)
            context.stroke(path, with: .color(.white), lineWidth: line.lineWidth + 10)
            
        case .rectangle:
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                let rect = CGRect(x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y))
                context.stroke(Path(rect), with: .color(line.color), lineWidth: line.lineWidth)
                if let text = line.text {
                    context.draw(Text(text).foregroundColor(line.color), in: rect)
                }
            }
            
        case .circle:
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                let rect = CGRect(x: min(start.x, end.x),
                                y: min(start.y, end.y),
                                width: abs(end.x - start.x),
                                height: abs(end.y - start.y))
                context.stroke(Path(ellipseIn: rect), with: .color(line.color), lineWidth: line.lineWidth)
                if let text = line.text {
                    context.draw(Text(text).foregroundColor(line.color), in: rect)
                }
            }
            
        case .arrow:
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                drawArrow(context: context, from: start, to: end, color: line.color, lineWidth: line.lineWidth)
            }
        case .text:
            if let position = line.points.first {
                if let text = line.text {
                    context.draw(
                        Text(text)
                            .foregroundColor(line.color),
                        at: position
                    )
                }
            }
            
        case .selection:
            if line.points.count >= 2 {
                let start = line.points[0]
                let end = line.points[1]
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                // Draw semi-transparent selection rectangle
                context.fill(
                    Path(rect),
                    with: .color(line.color)
                )
                // Draw border
                context.stroke(
                    Path(rect),
                    with: .color(.blue),
                    lineWidth: line.lineWidth
                )
            }
        case .deque, .linkedList:
            // No need to draw anything here since deques are handled by DequeView
            break
        case .grid, .hand:
            // No need to draw anything here since grids are handled by GridView
            break
        }
        
        // Add selection indicator if the element is selected
        if isSelected {
            switch line.tool {
            case .pen, .eraser:
                let bounds = line.points.reduce(CGRect.null) { rect, point in
                    rect.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
                }
                // Add padding to make the selection border visible
                let selectionRect = bounds.insetBy(dx: -5, dy: -5)
                let dash: [CGFloat] = [5, 5] // Creates a dashed pattern
                context.stroke(
                    Path(selectionRect),
                    with: .color(.blue),
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: dash
                    )
                )
                
            case .rectangle, .circle:
                if line.points.count >= 2 {
                    let start = line.points.first!
                    let end = line.points.last!
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    let selectionRect = rect.insetBy(dx: -5, dy: -5)
                    let dash: [CGFloat] = [5, 5]
                    context.stroke(
                        Path(selectionRect),
                        with: .color(.blue),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: dash
                        )
                    )
                }
                
            case .arrow:
                if line.points.count >= 2 {
                    let start = line.points.first!
                    let end = line.points.last!
                    let bounds = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    let selectionRect = bounds.insetBy(dx: -5, dy: -5)
                    let dash: [CGFloat] = [5, 5]
                    context.stroke(
                        Path(selectionRect),
                        with: .color(.blue),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: dash
                        )
                    )
                }
                
            case .text:
                if let position = line.points.first {
                    let textSize = CGSize(width: 100, height: 30) // Approximate text size
                    let selectionRect = CGRect(
                        x: position.x - textSize.width/2,
                        y: position.y - textSize.height/2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    let dash: [CGFloat] = [5, 5]
                    context.stroke(
                        Path(selectionRect),
                        with: .color(.blue),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: dash
                        )
                    )
                }
                
            case .deque, .linkedList:
                // No need for selection indicator since deques are handled by DequeView
                break
                
            case .selection:
                break // Don't draw selection indicator for selection tool itself
            case .grid, .hand:
                // No need for selection indicator since grids are handled by GridView
                break
            }
        }
    }
    
    private func drawArrow(context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color, lineWidth: CGFloat) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPoint1 = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle),
                                 y: end.y - arrowLength * sin(angle - arrowAngle))
        let arrowPoint2 = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle),
                                 y: end.y - arrowLength * sin(angle + arrowAngle))
        
        path.move(to: end)
        path.addLine(to: arrowPoint1)
        path.move(to: end)
        path.addLine(to: arrowPoint2)
        
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
    
    private func undo() {
        if let previousLines = undoStack.popLast() {
            redoStack.append(lines)
            lines = previousLines
            selectedShapeIndex = nil
            currentText = ""
        }
    }
    
    private func redo() {
        if let nextLines = redoStack.popLast() {
            undoStack.append(lines)
            lines = nextLines
            selectedShapeIndex = nil
            currentText = ""
        }
    }
    
    private func handleSelectionDrag(_ value: DragGesture.Value) {
        if currentLine == nil {
            currentLine = Line(points: [value.startLocation], color: .blue.opacity(0.3), lineWidth: 1, tool: .rectangle)
        }
        currentLine?.points = [value.startLocation, value.location]
    }
    
    private func handleSelectionEnd(_ value: DragGesture.Value) {
        guard let selection = currentLine else { return }
        currentLine = nil
        
        let selectionRect = CGRect(
            x: min(selection.points[0].x, selection.points[1].x),
            y: min(selection.points[0].y, selection.points[1].y),
            width: abs(selection.points[1].x - selection.points[0].x),
            height: abs(selection.points[1].y - selection.points[0].y))
        
        selectedElements.removeAll()
        for (index, line) in lines.enumerated() {
            if isLine(line, intersectingWith: selectionRect) {
                selectedElements.insert(index)
            }
        }
        
        // Switch to hand tool after making a selection
        if !selectedElements.isEmpty {
            selectedTool = .hand
        }
    }
    
    private func isLine(_ line: Line, intersectingWith rect: CGRect) -> Bool {
        switch line.tool {
        case .text:
            // For text, create a more precise selection area
            if let position = line.points.first {
                // Approximate text bounds based on the text content
                let textSize = (line.text ?? "").size(withAttributes: [.font: UIFont.systemFont(ofSize: 17)])
                let textRect = CGRect(
                    x: position.x - textSize.width/2,
                    y: position.y - textSize.height/2,
                    width: textSize.width,
                    height: textSize.height
                )
                return rect.intersects(textRect)
            }
            return false
            
        case .pen, .eraser:
            // For lines, check if any point is within the selection rectangle
            return line.points.contains { point in
                rect.contains(point)
            }
            
        case .rectangle, .circle:
            // For shapes, use the existing bounding box logic
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                let shapeBounds = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                return rect.intersects(shapeBounds)
            }
            return false
            
        case .arrow:
            // For arrows, check if either endpoint is within selection
            if line.points.count >= 2 {
                let start = line.points.first!
                let end = line.points.last!
                return rect.contains(start) || rect.contains(end)
            }
            return false
            
        default:
            return false
        }
    }
    
    private func applyDragToSelected() {
        let offsetElements = selectedElements.sorted().reversed()
        for index in offsetElements {
            var line = lines[index]
            line.points = line.points.map { CGPoint(
                x: $0.x + dragOffset.width,
                y: $0.y + dragOffset.height
            )}
            lines[index] = line
        }
    }
    
    private func copySelected() {
        undoStack.append(lines)
        redoStack.removeAll()
        
        // Get the current number of lines before adding copies
        let startIndex = lines.count
        
        // Create and add copies
        let newElements = selectedElements.map { lines[$0] }.map { line -> Line in
            var newLine = line
            newLine.points = line.points.map { CGPoint(
                x: $0.x + 20, // Offset copied elements slightly
                y: $0.y + 20
            )}
            return newLine
        }
        
        lines.append(contentsOf: newElements)
        
        // Clear old selection and select the newly copied elements
        selectedElements.removeAll()
        for i in 0..<newElements.count {
            selectedElements.insert(startIndex + i)
        }
        
        // Switch to hand tool to move the copies
        selectedTool = .hand
    }
    
    // Add this function to save the current text
    private func saveCurrentText() {
        if isShowingTextField && !currentText.isEmpty, let position = textPosition {
            let newLine = Line(
                points: [position],
                color: selectedColor,
                lineWidth: lineWidth,
                tool: .text,
                text: currentText
            )
            undoStack.append(lines)
            lines.append(newLine)
            redoStack.removeAll()
        }
    }
    
    private var dataStructuresLayer: some View {
        ZStack {
            // Modify the DequeView creation
            ForEach(deques) { dequeData in
                DequeView(
                    dequeData: dequeData,
                    isDraggingOverBin: $isDraggingOverBin,
                    binAnimation: $binAnimation,
                    deques: $deques
                )
            }
            
            // Display GridViews
            ForEach(grids) { gridData in
                GridView(
                    gridData: gridData,
                    arrayFormat: gridData.values,
                    isDraggingOverBin: $isDraggingOverBin,
                    binAnimation: $binAnimation,
                    grids: $grids
                )
            }
            
            // Modify the LinkedListView creation
            ForEach(linkedLists) { linkedListData in
                LinkedListView(
                    sequenceData: linkedListData,
                    isDraggingOverBin: $isDraggingOverBin,
                    binAnimation: $binAnimation,
                    lists: $linkedLists
                )
            }
        }
    }
    
    private var canvasLayer: some View {
        Canvas { context, size in
            for (index, line) in lines.enumerated() {
                let isSelected = selectedElements.contains(index)
                if isSelected && dragOffset != .zero {
                    var offsetLine = line
                    offsetLine.points = line.points.map { CGPoint(
                        x: $0.x + dragOffset.width,
                        y: $0.y + dragOffset.height
                    )}
                    drawElement(context: context, line: offsetLine, isSelected: true)
                } else {
                    drawElement(context: context, line: line, isSelected: isSelected)
                }
            }
            if let currentLine = currentLine {
                drawElement(context: context, line: currentLine, isSelected: false)
            }
        }
        .onTapGesture { location in
            print("Tap detected, selected tool: \(selectedTool)")
            if selectedTool == .deque {
                pendingDequePosition = location
                isShowingDequeAlert = true
                return
            } else if selectedTool == .grid {
                pendingGridPosition = location
                isShowingGridAlert = true
                return
            } else if selectedTool == .text {
                textPosition = location
                isShowingTextAlert = true
            } else if selectedTool == .linkedList {
                pendingLinkedListPosition = location
                isShowingLinkedListAlert = true
                return
            } else {
                handleTap(at: location)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if selectedTool == .text {
                        // Ignore drag for text tool
                        return
                    }
                    if selectedTool == .selection {
                        if !selectedElements.isEmpty {
                            dragOffset = value.translation
                        } else {
                            handleSelectionDrag(value)
                        }
                    } else if selectedTool == .text {
                        // No drag handling for text tool
                    } else {
                        handleDragChange(value)
                    }
                }
                .onEnded { value in
                    if selectedTool == .text {
                        // Ignore drag for text tool
                        return
                    }
                    if selectedTool == .selection {
                        if !selectedElements.isEmpty {
                            applyDragToSelected()
                        } else {
                            handleSelectionEnd(value)
                        }
                        dragOffset = .zero
                    } else if selectedTool == .text {
                        saveCurrentText()
                        textPosition = value.location
                        isShowingTextField = true
                        currentText = ""
                    } else {
                        handleDragEnd(value)
                    }
                }
        )
    }
}

#Preview {
    ContentView()
}

struct ImageToggleStyle: ToggleStyle {
    let image: String
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {  // Added small spacing for visual balance
            Image(systemName: image)
                .foregroundColor(.gray)
                .font(.system(size: 16))  // Adjust image size
                .frame(width: 20)  // Fixed width for consistency
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
                .scaleEffect(0.8)  // Scale down the toggle slightly
        }
    }
}

// New component to handle alerts
struct AlertsOverlay: View {
    @Binding var isShowingDequeAlert: Bool
    @Binding var isShowingTextAlert: Bool
    @Binding var isShowingGridAlert: Bool
    @Binding var isShowingLinkedListAlert: Bool
    @Binding var dequeInitialValues: String
    @Binding var linkedListInitialValues: String
    @Binding var currentText: String
    @Binding var gridArrayInput: String
    @Binding var pendingDequePosition: CGPoint?
    @Binding var pendingGridPosition: CGPoint?
    @Binding var pendingLinkedListPosition: CGPoint?
    @Binding var textPosition: CGPoint?
    @Binding var gridOrientation: GridOrientation
    @Binding var lines: [Line]
    @Binding var undoStack: [[Line]]
    @Binding var redoStack: [[Line]]
    @Binding var deques: [DSViewData<[String]>]
    @Binding var grids: [DSViewData<String>]
    @Binding var linkedLists: [DSViewData<[String]>]
    
    var body: some View {
        EmptyView()
            .alert("Enter Initial Values", isPresented: $isShowingDequeAlert) {
                TextField("e.g., 1,2,3 or leave empty", text: $dequeInitialValues)
                Button("OK") {
                    handleDequeAlert()
                }
                Button("Cancel", role: .cancel) {
                    dequeInitialValues = ""
                    pendingDequePosition = nil
                }
            }
            .alert("Enter Initial Values", isPresented: $isShowingLinkedListAlert) {
                TextField("e.g., 1,2,3 or leave empty", text: $linkedListInitialValues)
                Button("OK") {
                    handleLinkedListAlert()
                }
                Button("Cancel", role: .cancel) {
                    linkedListInitialValues = ""
                    pendingLinkedListPosition = nil
                }
            }
            .alert("Enter Text", isPresented: $isShowingTextAlert) {
                TextField("Text", text: $currentText)
                Button("OK") {
                    handleTextAlert()
                }
                Button("Cancel", role: .cancel) {
                    currentText = ""
                    textPosition = nil
                }
            }
            .alert("Create Grid", isPresented: $isShowingGridAlert) {
                TextField("Array (e.g., [[1,2],[3,4]])", text: $gridArrayInput)
                Button("Row × Col") {
                    handleGridAlert(orientation: .rowByCol)
                }
                Button("Col × Row") {
                    handleGridAlert(orientation: .colByRow)
                }
                Button("Cancel", role: .cancel) {
                    gridArrayInput = ""
                    pendingGridPosition = nil
                }
            } message: {
                Text("Enter array in format [[1,2],[3,4]]")
            }
    }
    
    private func handleDequeAlert() {
        if let position = pendingDequePosition {
            let id = UUID()
            let initialValues = dequeInitialValues.isEmpty ? 
                [""] : 
                dequeInitialValues
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            let dequeData = DSViewData(id: id, position: position, initialValues: initialValues)
            deques.append(dequeData)
        }
        pendingDequePosition = nil
        dequeInitialValues = ""
    }
    
    private func handleLinkedListAlert() {
        if let position = pendingLinkedListPosition {
            let id = UUID()
            let initialValues = linkedListInitialValues.isEmpty ?
                [""] :
                linkedListInitialValues
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            let listData = DSViewData(id: id, position: position, initialValues: initialValues)
            linkedLists.append(listData)
        }
        pendingLinkedListPosition = nil
        linkedListInitialValues = ""
    }
    
    private func handleTextAlert() {
        if !currentText.isEmpty, let position = textPosition {
            let newLine = Line(
                points: [position],
                color: .black,
                lineWidth: 3,
                tool: .text,
                text: currentText
            )
            undoStack.append(lines)
            lines.append(newLine)
            redoStack.removeAll()
        }
        currentText = ""
        textPosition = nil
    }
    
    private func handleGridAlert(orientation: GridOrientation) {
        if let position = pendingGridPosition {
            let id = UUID()
            let gridData = DSViewData(id: id, position: position, initialValues: gridArrayInput)
            grids.append(gridData)
        }
        pendingGridPosition = nil
    }
}
