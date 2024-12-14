import SwiftUI

struct DragToDeleteModifier: ViewModifier {
    @Binding var position: CGPoint
    @Binding var isDraggingOverBin: Bool
    @Binding var binAnimation: Bool
    let objectSize: CGSize
    let onDelete: () -> Void
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content.gesture(
                DragGesture()
                    .onChanged { value in
                        // Update position
                        let newPosition = value.location
                        position = newPosition
                        
                        // Calculate bounds
                        let windowBounds = CGRect(origin: .zero, size: geometry.size)
                        let objectBounds = CGRect(
                            x: newPosition.x - objectSize.width/2,
                            y: newPosition.y - objectSize.height/2,
                            width: objectSize.width,
                            height: objectSize.height
                        )
                        
                        // Check deletion zone
                        let deleteZone = CGRect(
                            x: windowBounds.width * 0.8,
                            y: windowBounds.height * 0.8,
                            width: windowBounds.width * 0.2,
                            height: windowBounds.height * 0.2
                        )
                        
                        isDraggingOverBin = deleteZone.intersects(objectBounds)
                        binAnimation = isDraggingOverBin
                    }
                    .onEnded { value in
                        let windowBounds = CGRect(origin: .zero, size: geometry.size)
                        let objectBounds = CGRect(
                            x: value.location.x - objectSize.width/2,
                            y: value.location.y - objectSize.height/2,
                            width: objectSize.width,
                            height: objectSize.height
                        )
                        
                        let deleteZone = CGRect(
                            x: windowBounds.width * 0.8,
                            y: windowBounds.height * 0.8,
                            width: windowBounds.width * 0.2,
                            height: windowBounds.height * 0.2
                        )
                        
                        if deleteZone.intersects(objectBounds) {
                            withAnimation {
                                onDelete()
                                binAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    binAnimation = false
                                }
                            }
                        }
                        isDraggingOverBin = false
                    }
            )
        }
    }
}

// Extension to make it easier to use
extension View {
    func dragToDelete(
        position: Binding<CGPoint>,
        isDraggingOverBin: Binding<Bool>,
        binAnimation: Binding<Bool>,
        objectSize: CGSize,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(DragToDeleteModifier(
            position: position,
            isDraggingOverBin: isDraggingOverBin,
            binAnimation: binAnimation,
            objectSize: objectSize,
            onDelete: onDelete
        ))
    }
} 
