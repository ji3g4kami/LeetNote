import SwiftUI

struct LinkedListView: View {
    @ObservedObject var sequenceData: DSViewData<[String]>
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    @Binding var lists: [DSViewData<[String]>]

    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(sequenceData.values.count) * 80,
                height: 60
            )
            
            ZStack {
                // Draw lines between nodes
                ForEach(0..<(sequenceData.values.count - 1), id: \.self) { index in
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
                    ForEach(Array(sequenceData.values.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 4) {
                            // Node
                            ZStack {
                                Circle()
                                    .stroke(Color.black, lineWidth: 1)
                                    .background(Circle().fill(Color(UIColor.systemBackground)))
                                    .overlay(
                                        TextField("", text: Binding(
                                            get: { value },
                                            set: { sequenceData.values[index] = $0 }
                                        ))
                                        .multilineTextAlignment(.center)
                                    )
                                    .frame(width: 50, height: 50)
                            }
                            
                            // Controls
                            HStack(spacing: 4) {
                                Button(action: {
                                    sequenceData.values.remove(at: index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                }
                                
                                Button(action: {
                                    sequenceData.values.insert("", at: index + 1)
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
            .position(x: sequenceData.position.x, y: sequenceData.position.y)
            .dragToDelete(
                position: $sequenceData.position,
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                objectSize: objectSize
            ) {
                if let index = lists.firstIndex(where: { $0.id == sequenceData.id }) {
                    lists.remove(at: index)
                }
            }
        }
    }
}

#Preview {
    LinkedListView(
        sequenceData: DSViewData<[String]>(
            position: CGPoint(x: 200, y: 300),
            initialValues: ["1", "2", "3"]),
        isDraggingOverBin: .constant(false),
        binAnimation: .constant(false),
        lists: .constant([])
    )
}
