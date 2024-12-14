import SwiftUI

struct GridView: View {
    @ObservedObject var gridData: DSViewData<String>
    @State private var rows: Int
    @State private var cols: Int
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let orientation: GridOrientation
    let parsedValues: [[String]]
    @Binding var grids: [DSViewData<String>]
    
    init(gridData: DSViewData<String>,
         arrayFormat: String,
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         orientation: GridOrientation = .rowByCol,
         grids: Binding<[DSViewData<String>]>
    ) {
        self.gridData = gridData
        self.orientation = orientation
        self._isDraggingOverBin = isDraggingOverBin
        self._binAnimation = binAnimation
        self._grids = grids
        
        let parsedValues = GridView.parseAndTranspose(arrayFormat, orientation: orientation)
        self.parsedValues = parsedValues
        self._rows = State(initialValue: parsedValues.count)
        self._cols = State(initialValue: parsedValues.first?.count ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(cols) * 40,
                height: CGFloat(rows) * 40
            )

            VStack(spacing: 1) {
                ForEach(parsedValues.indices, id: \.self) { (row: Int) in
                    HStack(spacing: 1) {
                        ForEach(parsedValues[row].indices, id: \.self) { (col: Int) in
                            createGridCell(row: row, col: col)
                        }
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .position(x: gridData.position.x, y: gridData.position.y)
            .dragToDelete(
                position: $gridData.position,
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                objectSize: objectSize, onDelete: {
                    if let index = grids.firstIndex(where: { $0.id == gridData.id }) {
                        grids.remove(at: index)
                    }
                }
            )
        }
    }
    
    private func createGridCell(row: Int, col: Int) -> some View {
        Rectangle()
            .stroke(Color.black, lineWidth: 1)
            .overlay(
                Text(parsedValues[row][col])
                    .multilineTextAlignment(.center)
            )
            .frame(width: 40, height: 40)
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
