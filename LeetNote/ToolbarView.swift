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
            ForEach(DrawingTool.allCases, id: \.self) { tool in
                ToolButton(
                    tool: tool,
                    selectedTool: $selectedTool,
                    saveCurrentText: saveCurrentText
                )
            }

            // Color picker
            ColorPicker("", selection: $selectedColor)
                .padding()
                .accessibilityLabel("Color Picker")

            // Undo/Redo buttons
            Button(action: undoAction) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!canUndo)
            .padding()
            .accessibilityLabel("Undo")

            Button(action: redoAction) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!canRedo)
            .padding()
            .accessibilityLabel("Redo")

            // Copy button (only when elements are selected)
            if !selectedElements.isEmpty {
                Button(action: copyAction) {
                    Image(systemName: "doc.on.doc")
                }
                .padding()
                .accessibilityLabel("Copy Selected Elements")
            }

            // Trash and Layer Controls
            HStack(spacing: 4) {
                Button(action: clearAction) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Clear All")

                Toggle("", isOn: $showDataStructuresOnTop)
                    .toggleStyle(ImageToggleStyle(image: "square.stack.3d.up"))
                    .padding()
                    .accessibilityLabel("Show Data Structures On Top")
            }
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

struct ToolButton: View {
    let tool: DrawingTool
    @Binding var selectedTool: DrawingTool
    let saveCurrentText: () -> Void

    var body: some View {
        Button(action: {
            saveCurrentText()
            withAnimation {
                selectedTool = tool
            }
        }) {
            Image(systemName: tool.iconName)
                .foregroundColor(selectedTool == tool ? .blue : .gray)
        }
        .padding()
        .accessibilityLabel("\(tool.iconName) Tool")
    }
}
