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
    case grid
}

struct DequeView: View {
    @State private var position: CGPoint
    @State private var values: [String]
    @Binding var positions: [UUID: CGPoint]
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let id: UUID
    
    init(initialPosition: CGPoint, 
         initialValues: [String] = [""], 
         positions: Binding<[UUID: CGPoint]>, 
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         id: UUID) {
        _position = State(initialValue: initialPosition)
        _values = State(initialValue: initialValues)
        _positions = positions
        _isDraggingOverBin = isDraggingOverBin
        _binAnimation = binAnimation
        self.id = id
    }
    
    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                let newPosition = CGPoint(
                    x: value.location.x,
                    y: value.location.y
                )
                position = newPosition
                positions[id] = newPosition
                
                // Get the window bounds
                let windowBounds = UIScreen.main.bounds
                
                // Calculate object bounds (approximate size based on content)
                let objectWidth: CGFloat = CGFloat(values.count) * 40 + 60 // 40 per cell + padding for buttons
                let objectHeight: CGFloat = 60 // Approximate height including buttons
                let objectBounds = CGRect(
                    x: newPosition.x - objectWidth/2,
                    y: newPosition.y - objectHeight/2,
                    width: objectWidth,
                    height: objectHeight
                )
                
                // Define deletion zone in bottom-right corner
                let deleteZone = CGRect(
                    x: windowBounds.width * 0.8,
                    y: windowBounds.height * 0.8,
                    width: windowBounds.width * 0.2,
                    height: windowBounds.height * 0.2
                )
                
                // Check if the object's bounds intersect with the deletion zone
                if deleteZone.intersects(objectBounds) {
                    isDraggingOverBin = true
                    binAnimation = true
                } else {
                    isDraggingOverBin = false
                    binAnimation = false
                }
            }
            .onEnded { value in
                let windowBounds = UIScreen.main.bounds
                
                // Calculate object bounds
                let objectWidth: CGFloat = CGFloat(values.count) * 40 + 60
                let objectHeight: CGFloat = 60
                let objectBounds = CGRect(
                    x: value.location.x - objectWidth/2,
                    y: value.location.y - objectHeight/2,
                    width: objectWidth,
                    height: objectHeight
                )
                
                // Define deletion zone
                let deleteZone = CGRect(
                    x: windowBounds.width * 0.8,
                    y: windowBounds.height * 0.8,
                    width: windowBounds.width * 0.2,
                    height: windowBounds.height * 0.2
                )
                
                if deleteZone.intersects(objectBounds) {
                    withAnimation {
                        positions.removeValue(forKey: id)
                        binAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            binAnimation = false
                        }
                    }
                }
                isDraggingOverBin = false
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

// Helper function to parse array format


struct GridView: View {
    @State private var position: CGPoint
    @State private var values: [[String]]
    @State private var rows: Int
    @State private var cols: Int
    @Binding var positions: [UUID: CGPoint]
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let id: UUID
    
    init(initialPosition: CGPoint,
         arrayFormat: String,
         positions: Binding<[UUID: CGPoint]>,
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         id: UUID) {
        _position = State(initialValue: initialPosition)
        
        // Parse array format input [[1,2],[3,4]]
        let parsedValues = GridView.parseArrayFormat(arrayFormat)
        _values = State(initialValue: parsedValues)
        _rows = State(initialValue: parsedValues.count)
        _cols = State(initialValue: parsedValues.first?.count ?? 0)
        _positions = positions
        _isDraggingOverBin = isDraggingOverBin
        _binAnimation = binAnimation
        self.id = id
    }
    
    var body: some View {
        let dragGesture = DragGesture()
            .onChanged { value in
                let newPosition = CGPoint(
                    x: value.location.x,
                    y: value.location.y
                )
                position = newPosition
                positions[id] = newPosition
                
                // Get the window bounds
                let windowBounds = UIScreen.main.bounds
                
                // Calculate object bounds
                let objectWidth: CGFloat = CGFloat(cols) * 40 // 40 per cell
                let objectHeight: CGFloat = CGFloat(rows) * 40
                let objectBounds = CGRect(
                    x: newPosition.x - objectWidth/2,
                    y: newPosition.y - objectHeight/2,
                    width: objectWidth,
                    height: objectHeight
                )
                
                // Define deletion zone in bottom-right corner
                let deleteZone = CGRect(
                    x: windowBounds.width * 0.8,
                    y: windowBounds.height * 0.8,
                    width: windowBounds.width * 0.2,
                    height: windowBounds.height * 0.2
                )
                
                // Check if the object's bounds intersect with the deletion zone
                if deleteZone.intersects(objectBounds) {
                    isDraggingOverBin = true
                    binAnimation = true
                } else {
                    isDraggingOverBin = false
                    binAnimation = false
                }
            }
            .onEnded { value in
                let windowBounds = UIScreen.main.bounds
                
                // Calculate object bounds
                let objectWidth: CGFloat = CGFloat(cols) * 40
                let objectHeight: CGFloat = CGFloat(rows) * 40
                let objectBounds = CGRect(
                    x: value.location.x - objectWidth/2,
                    y: value.location.y - objectHeight/2,
                    width: objectWidth,
                    height: objectHeight
                )
                
                // Define deletion zone
                let deleteZone = CGRect(
                    x: windowBounds.width * 0.8,
                    y: windowBounds.height * 0.8,
                    width: windowBounds.width * 0.2,
                    height: windowBounds.height * 0.2
                )
                
                if deleteZone.intersects(objectBounds) {
                    withAnimation {
                        positions.removeValue(forKey: id)
                        binAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            binAnimation = false
                        }
                    }
                }
                isDraggingOverBin = false
            }
        
        return VStack(spacing: 1) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<cols, id: \.self) { col in
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
                            .overlay(
                                TextField("", text: Binding(
                                    get: { values[row][col] },
                                    set: { values[row][col] = $0 }
                                ))
                                .multilineTextAlignment(.center)
                            )
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .position(x: position.x, y: position.y)
        .gesture(dragGesture)
    }
    
    static func parseArrayFormat(_ input: String) -> [[String]] {
        // Remove whitespace
        var cleaned = input.replacingOccurrences(of: " ", with: "")
        
        // Ensure the string starts and ends with [[...]]
        if cleaned.hasPrefix("[[") && cleaned.hasSuffix("]]") {
            // Remove outer brackets
            cleaned = String(cleaned.dropFirst(2).dropLast(2))
            
            // Split into rows by "],["
            let rows = cleaned.components(separatedBy: "],[")
            
            return rows.map { row in
                // Clean up any remaining brackets
                let cleanRow = row.replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                // Split row into values
                return cleanRow.components(separatedBy: ",")
            }
        }
        
        return [[]]  // Return empty grid if parsing fails
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
    @State private var isShowingTextAlert = false
    @State private var gridPositions: [UUID: CGPoint] = [:]
    @State private var isShowingGridAlert = false
    @State private var gridArrayInput = ""
    @State private var pendingGridPosition: CGPoint?
    @State private var isDraggingOverBin = false
    @State private var binAnimation = false
    @State private var showDataStructuresOnTop = true
    
    var body: some View {
        VStack {
            // Toolbar
            HStack {
                // Drawing tools
                ForEach([DrawingTool.pen, .eraser, .rectangle, .circle, .arrow, .text, .selection, .deque, .grid], id: \.self) { tool in
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
                
                // Group the trash and layer controls together
                HStack(spacing: 4) {  // Reduced spacing between these related controls
                    Button(action: {
                        undoStack.append(lines)
                        lines.removeAll()
                        redoStack.removeAll()
                        selectedElements.removeAll()
                        currentText = ""
                        dequePositions.removeAll()
                        gridPositions.removeAll()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    Toggle("", isOn: $showDataStructuresOnTop)
                           .toggleStyle(ImageToggleStyle(image: "square.stack.3d.up"))
                           .padding()
                }
            }
            
            // Canvas
            ZStack {
                if !showDataStructuresOnTop {
                    // Data Structures Layer
                    dataStructuresLayer
                }
                
                // Canvas Layer
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
        .alert("Enter Text", isPresented: $isShowingTextAlert) {
            TextField("Text", text: $currentText)
            Button("OK") {
                if !currentText.isEmpty, let position = textPosition {
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
                currentText = ""
                textPosition = nil
            }
            Button("Cancel", role: .cancel) {
                currentText = ""
                textPosition = nil
            }
        }
        .alert("Create Grid", isPresented: $isShowingGridAlert) {
            TextField("Array (e.g., [[1,2],[3,4]])", text: $gridArrayInput)
            Button("OK") {
                if let position = pendingGridPosition {
                    let id = UUID()
                    gridPositions[id] = position
                }
                pendingGridPosition = nil
            }
            Button("Cancel", role: .cancel) {
                gridArrayInput = ""
                pendingGridPosition = nil
            }
        } message: {
            Text("Enter array in format [[1,2],[3,4]]")
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
        case .deque: return "rectangle.split.3x1"
        case .grid: return "rectangle.split.3x3"
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
        case .grid:
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
                
            case .deque:
                // No need for selection indicator since deques are handled by DequeView
                break
                
            case .selection:
                break // Don't draw selection indicator for selection tool itself
            case .grid:
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
    
    private var dataStructuresLayer: some View {
        ZStack {
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
                    DequeView(
                        initialPosition: position,
                        initialValues: initialValues,
                        positions: $dequePositions,
                        isDraggingOverBin: $isDraggingOverBin,
                        binAnimation: $binAnimation,
                        id: id
                    )
                }
            }
            
            // Display GridViews
            ForEach(Array(gridPositions.keys), id: \.self) { id in
                if let position = gridPositions[id] {
                    GridView(
                        initialPosition: position,
                        arrayFormat: gridArrayInput,
                        positions: $gridPositions,
                        isDraggingOverBin: $isDraggingOverBin,
                        binAnimation: $binAnimation,
                        id: id
                    )
                }
            }
        }
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
