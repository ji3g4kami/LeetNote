import SwiftUI

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var currentText: String
    @Binding var selectedElements: Set<Int>
    @Binding var showDataStructuresOnTop: Bool
    @Binding var lines: [Line]
    let undoAction: () -> Void
    let redoAction: () -> Void
    let copyAction: () -> Void
    let clearAction: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    let saveCurrentText: () -> Void
    
    var body: some View {
        HStack {
            // Drawing tools
            ForEach([DrawingTool.pen, .eraser, .rectangle, .circle, .arrow, .text, .selection, .hand, .deque, .grid], id: \.self) { tool in
                Button(action: {
                    saveCurrentText()
                    
                    // Switch tool and clean up
                    selectedTool = tool
                    if tool != .hand {
                        selectedElements.removeAll()
                    }
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
            Button(action: undoAction) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            .padding()
            
            Button(action: redoAction) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
            .padding()
            
            if !selectedElements.isEmpty {
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                }
                .padding()
            }
            
            // Group the trash and layer controls together
            HStack(spacing: 4) {
                Button(action: clearAction) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                
                Spacer()
                Toggle("", isOn: $showDataStructuresOnTop)
                       .toggleStyle(ImageToggleStyle(image: "square.stack.3d.up"))
                       .padding()
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
        case .hand: return "hand.draw"
        case .deque: return "rectangle.split.3x1"
        case .grid: return "rectangle.split.3x3"
        }
    }
}

#Preview {
    ToolbarView(
        selectedTool: .constant(.pen),
        selectedColor: .constant(.black),
        currentText: .constant(""),
        selectedElements: .constant([]),
        showDataStructuresOnTop: .constant(false),
        lines: .constant([]),
        undoAction: {},
        redoAction: {},
        copyAction: {},
        clearAction: {},
        canUndo: false,
        canRedo: false,
        saveCurrentText: {}
    )
}
