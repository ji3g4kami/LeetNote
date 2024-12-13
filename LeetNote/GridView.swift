import SwiftUI

struct GridView: View {
    @State private var position: CGPoint
    @State private var values: [[String]]
    @State private var rows: Int
    @State private var cols: Int
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let id: UUID
    let orientation: GridOrientation
    
    init(initialPosition: CGPoint,
         arrayFormat: String,
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         id: UUID,
         orientation: GridOrientation = .rowByCol) {
        _position = State(initialValue: initialPosition)
        let parsedValues = GridView.parseAndTranspose(arrayFormat, orientation: orientation)
        _values = State(initialValue: parsedValues)
        _rows = State(initialValue: parsedValues.count)
        _cols = State(initialValue: parsedValues.first?.count ?? 0)
        _isDraggingOverBin = isDraggingOverBin
        _binAnimation = binAnimation
        self.id = id
        self.orientation = orientation
    }

    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(cols) * 40,
                height: CGFloat(rows) * 40
            )

            VStack(spacing: 1) {
                ForEach(values.indices, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(values[row].indices, id: \.self) { col in
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
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                id: id,
                objectSize: objectSize, onDelete: {}
            )
        }
    }

    static func parseAndTranspose(_ input: String, orientation: GridOrientation) -> [[String]] {
        let parsedValues = parseArrayFormat(input)
        return orientation == .rowByCol ? parsedValues : transpose(parsedValues)
    }

    static func parseArrayFormat(_ input: String) -> [[String]] {
        var cleaned = input.replacingOccurrences(of: " ", with: "")
        if cleaned.hasPrefix("[[") && cleaned.hasSuffix("]]") {
            cleaned = String(cleaned.dropFirst(2).dropLast(2))
            let rows = cleaned.components(separatedBy: "],[")
            let parsedRows = rows.map { row in
                let cleanRow = row.replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return cleanRow.isEmpty ? [] : cleanRow.components(separatedBy: ",")
            }
            let maxLength = parsedRows.map { $0.count }.max() ?? 0
            return parsedRows.map { row in
                let padding = Array(repeating: "", count: maxLength - row.count)
                return row + padding
            }
        }
        return [[]]
    }

    static func transpose(_ array: [[String]]) -> [[String]] {
        guard let firstRow = array.first else { return [[]] }
        return (0..<firstRow.count).map { colIndex in
            array.map { row in colIndex < row.count ? row[colIndex] : "" }
        }
    }
}
