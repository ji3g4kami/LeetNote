import SwiftUI

struct LinkedListView: View {
    @State private var values: [String]
    @State private var position: CGPoint
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    @Binding var lists: [[String]]
    let id: UUID

    init(initialValues: [String],
         initialPosition: CGPoint,
         isDraggingOverBin: Binding<Bool>,
         binAnimation: Binding<Bool>,
         lists: Binding<[[String]]>,
         id: UUID) {
        _values = State(initialValue: initialValues)
        _position = State(initialValue: initialPosition)
        _isDraggingOverBin = isDraggingOverBin
        _binAnimation = binAnimation
        _lists = lists
        self.id = id
    }

    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(values.count) * 80,
                height: 60
            )
            
            ZStack {
                // Draw lines between nodes
                ForEach(0..<(values.count - 1), id: \.self) { index in
                    Path { path in
                        let startX = CGFloat(index) * 80 + 65
                        let endX = CGFloat(index + 1) * 80 + 15
                        path.move(to: CGPoint(x: startX, y: 21))
                        path.addLine(to: CGPoint(x: endX, y: 21))
                    }
                    .stroke(Color.gray, lineWidth: 2)
                }
                
                // Nodes
                HStack(spacing: 30) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 4) {
                            // Node
                            ZStack {
                                Circle()
                                    .stroke(Color.black, lineWidth: 1)
                                    .background(Circle().fill(Color(UIColor.systemBackground)))
                                    .overlay(
                                        TextField("", text: Binding(
                                            get: { value },
                                            set: { values[index] = $0 }
                                        ))
                                        .multilineTextAlignment(.center)
                                    )
                                    .frame(width: 50, height: 50)
                            }
                            
                            // Controls
                            HStack(spacing: 4) {
                                Button(action: {
                                    values.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                }
                                
                                Button(action: {
                                    values.insert("", at: index + 1)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                }
                .frame(width: objectSize.width, height: objectSize.height)
            }
            .frame(width: objectSize.width, height: objectSize.height)
            .position(x: position.x, y: position.y)
            .dragToDelete(
                position: $position,
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                id: id,
                objectSize: objectSize
            ) {
                if let index = lists.firstIndex(where: { $0 == values }) {
                    lists.remove(at: index)
                }
            }
        }
    }
}

#Preview {
    return LinkedListView(
        initialValues: ["1", "2", "3"],
        initialPosition: CGPoint(x: 200, y: 300),
        isDraggingOverBin: .constant(false),
        binAnimation: .constant(false),
        lists: .constant([]),
        id: UUID()
    )
}
