import SwiftUI

struct GridView: View {
    @State private var position: CGPoint
    @State private var values: [[String]]
    @State private var rows: Int
    @State private var cols: Int
    @Binding var positions: [UUID: CGPoint]
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let id: UUID
    let orientation: GridOrientation
    
    init(initialPosition: CGPoint,
         arrayFormat: String,
         positions: Binding<[UUID: CGPoint]>,
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         id: UUID,
         orientation: GridOrientation = .rowByCol) {
        _position = State(initialValue: initialPosition)
        
        self.orientation = orientation
        
        // Parse array format input [[1,2],[3,4]]
        let parsedValues = GridView.parseArrayFormat(arrayFormat)
        
        switch orientation {
        case .rowByCol:
            _values = State(initialValue: parsedValues)
            _rows = State(initialValue: parsedValues.count)
            _cols = State(initialValue: parsedValues.first?.count ?? 0)
        case .colByRow:
            // Transpose the array for col×row orientation
            let transposed = GridView.transpose(parsedValues)
            _values = State(initialValue: transposed)
            _rows = State(initialValue: transposed.count)
            _cols = State(initialValue: transposed.first?.count ?? 0)
        }
        _positions = positions
        _isDraggingOverBin = isDraggingOverBin
        _binAnimation = binAnimation
        self.id = id
    }
    
    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(cols) * 40,
                height: CGFloat(rows) * 40
            )
            
            VStack(spacing: 1) {
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
            .dragToDelete(
                position: $position,
                positions: $positions,
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                id: id,
                objectSize: objectSize
            ) {
                positions.removeValue(forKey: id)
                binAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    binAnimation = false
                }
            }
            // Add keyboard delete support
            .keyboardShortcut(.delete, modifiers: [])
            .onKeyPress { press in
                if press.key == .delete || press.key == .delete {
                    withAnimation {
                        positions.removeValue(forKey: id)
                        binAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            binAnimation = false
                        }
                    }
                    return .handled
                }
                return .ignored
            }
            .focusable()
        }
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
            
            // Parse rows and find maximum length
            var parsedRows = rows.map { row in
                // Clean up any remaining brackets
                let cleanRow = row.replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                // Split row into values
                return cleanRow.components(separatedBy: ",")
            }
            
            // Find the maximum row length
            let maxLength = parsedRows.map { $0.count }.max() ?? 0
            
            // Pad shorter rows with empty strings
            return parsedRows.map { row in
                let padding = Array(repeating: "", count: maxLength - row.count)
                return row + padding
            }
        }
        
        return [[]]  // Return empty grid if parsing fails
    }
    
    static func transpose(_ array: [[String]]) -> [[String]] {
        guard let firstRow = array.first else { return [[]] }
        return (0..<firstRow.count).map { colIndex in
            array.map { row in
                colIndex < row.count ? row[colIndex] : ""
            }
        }
    }
}

