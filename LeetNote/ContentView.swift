import SwiftUI

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var tool: DrawingTool
    var text: String?
}

enum DrawingTool {
    case pen
    case eraser
    case rectangle
    case circle
    case arrow
    case text
    case selection
    case deque
}

struct DequeView: View {
    @State private var position: CGPoint
    @State private var values: [String]
    
    init(initialPosition: CGPoint, initialValues: [String] = [""]) {
        _position = State(initialValue: initialPosition)
        _values = State(initialValue: initialValues)
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
                Button(action: {
                    if !values.isEmpty {
                        values.removeFirst()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                Button(action: {
                    values.insert("", at: 0)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .offset(x: 10)
            .zIndex(1)
            
            // Deque cells
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
            .background(Color(UIColor.systemBackground))
            
            // Back controls
            VStack(spacing: 4) {
                Button(action: {
                    if !values.isEmpty {
                        values.removeLast()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
                Button(action: {
                    values.append("")
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
    @State private var dequePositions: [UUID: CGPoint] = [:]
    @State private var isShowingDequeAlert = false
    @State private var dequeInitialValues = ""
    @State private var pendingDequePosition: CGPoint?
    
    var body: some View {
        VStack {
            // Toolbar
            HStack {
                // Drawing tools
                ForEach([DrawingTool.pen, .eraser, .rectangle, .circle, .arrow, .text, .selection, .deque], id: \.self) { tool in
                    Button(action: {
                        // Save current text if exists
                        saveCurrentText()
                        
                        // Switch tool and clean up
                        selectedTool = tool
                        selectedElements.removeAll()
                        isShowingTextField = false
                        currentText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                     to: nil,
                                                     from: nil,
                                                     for: nil)
                    }) {
                        Image(systemName: toolIcon(for: tool))
                            .foregroundColor(selectedTool == tool ? .blue : .gray)
                    }
                    .padding()
                }
                
                // Color picker
                ColorPicker("", selection: $selectedColor)
                    .padding()
                
                // Undo/Redo buttons
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(undoStack.isEmpty)
                .padding()
                
                Button(action: redo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(redoStack.isEmpty)
                .padding()
                
                if !selectedElements.isEmpty {
                    Button(action: copySelected) {
                        Image(systemName: "doc.on.doc")
                    }
                    .padding()
                }
            }
            
            // Canvas
            ZStack {
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
                
                // Separate the tap gesture from other gestures
                .onTapGesture { location in
                    print("Tap detected, selected tool: \(selectedTool)") // Debug print
                    if selectedTool == .deque {
                        pendingDequePosition = location
                        isShowingDequeAlert = true
                        return
                    } else if selectedTool == .text {
                        textPosition = location
                        isShowingTextField = true
                        currentText = ""
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
                
                // Display DequeViews
                ForEach(Array(dequePositions.keys), id: \.self) { id in
                    if let position = dequePositions[id] {
                        let initialValues = dequeInitialValues.isEmpty ? 
                            [""] : 
                            dequeInitialValues
                                .replacingOccurrences(of: "[", with: "")
                                .replacingOccurrences(of: "]", with: "")
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                        DequeView(initialPosition: position, initialValues: initialValues)
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
                        .onChange(of: currentText) { newValue in
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
        .alert("Enter Initial Values", isPresented: $isShowingDequeAlert) {
            TextField("e.g., 1,2,3 or leave empty", text: $dequeInitialValues)
            Button("OK") {
                if let position = pendingDequePosition {
                    let id = UUID()
                    dequePositions[id] = position
                }
                pendingDequePosition = nil
            }
            Button("Cancel", role: .cancel) {
                dequeInitialValues = ""
                pendingDequePosition = nil
            }
        }
    }
    
    private func toolIcon(for tool: DrawingTool) -> String {
        switch tool {
        case .pen: return "pencil"
        case .eraser: return "eraser"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .arrow: return "arrow.right"
        case .text: return "text.cursor"
        case .selection: return "lasso"
        case .deque: return "square.stack"
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value) {
        let point = value.location
        if currentLine == nil {
            currentLine = Line(points: [point], color: selectedColor, lineWidth: lineWidth, tool: selectedTool)
        } else {
            currentLine?.points.append(point)
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        if let line = currentLine {
            undoStack.append(lines)
            redoStack.removeAll()
            lines.append(line)
        }
        currentLine = nil
    }
    
    private func handleTap(at location: CGPoint) {
        if selectedTool == .selection {
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
        case .deque:
            // No need to draw anything here since deques are handled by DequeView
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
                
            case .deque:
                // No need for selection indicator since deques are handled by DequeView
                break
                
            case .selection:
                break // Don't draw selection indicator for selection tool itself
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
            height: abs(selection.points[1].y - selection.points[0].y)
        )
        
        selectedElements.removeAll()
        for (index, line) in lines.enumerated() {
            if isLine(line, intersectingWith: selectionRect) {
                selectedElements.insert(index)
            }
        }
    }
    
    private func isLine(_ line: Line, intersectingWith rect: CGRect) -> Bool {
        // Simple bounding box check
        let lineBounds = line.points.reduce(CGRect.null) { rect, point in
            rect.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        return rect.intersects(lineBounds)
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
        
        let newElements = selectedElements.map { lines[$0] }.map { line -> Line in
            var newLine = line
            newLine.points = line.points.map { CGPoint(
                x: $0.x + 20, // Offset copied elements slightly
                y: $0.y + 20
            )}
            return newLine
        }
        
        lines.append(contentsOf: newElements)
        selectedElements.removeAll()
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
}

#Preview {
    ContentView()
}
