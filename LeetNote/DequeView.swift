import SwiftUI

struct DequeView: View {
    @ObservedObject var dequeData: DequeData
    @Binding var positions: [UUID: CGPoint]
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    @Binding var deques: [DequeData]
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        GeometryReader { geometry in
            let objectSize = CGSize(
                width: CGFloat(dequeData.values.count) * 40 + 60,
                height: 60
            )
            
            HStack(spacing: 1) {
                // Front controls
                VStack(spacing: 4) {
                    Button(action: {
                        if !dequeData.values.isEmpty {
                            dequeData.values.removeFirst()
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    Button(action: {
                        dequeData.values.insert("", at: 0)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .offset(x: 10)
                .zIndex(1)
                
                // Deque cells
                HStack(spacing: 1) {
                    ForEach(Array(dequeData.values.enumerated()), id: \.offset) { index, value in
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
                            .overlay(
                                TextField("", text: Binding(
                                    get: { value },
                                    set: { dequeData.values[index] = $0 }
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
                        if !dequeData.values.isEmpty {
                            dequeData.values.removeLast()
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    Button(action: {
                        dequeData.values.append("")
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .offset(x: -10)
                .zIndex(1)
            }
            .position(x: dequeData.position.x, y: dequeData.position.y)
            .dragToDelete(
                position: $dequeData.position,
                positions: $positions,
                isDraggingOverBin: $isDraggingOverBin,
                binAnimation: $binAnimation,
                id: dequeData.id,
                objectSize: objectSize
            ) {
                positions.removeValue(forKey: dequeData.id)
                if let index = deques.firstIndex(where: { $0.id == dequeData.id }) {
                    deques.remove(at: index)
                }
            }
        }
    }
}
