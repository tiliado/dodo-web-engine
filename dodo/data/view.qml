import QtQuick 2.0
import QtQuick.Controls 1.2
import QtQuick.Layouts 1.3

RowLayout {
    id: layout
    GridLayout {
        id: gridLayout
        rows: 2
        flow: GridLayout.TopToBottom
        property int margin: 20
        rowSpacing: margin * 0.5
        columnSpacing: margin * 0.5
        Layout.margins: margin * 1.0

        TextField {
            focus: true
            placeholderText: "Enter text to add..."
            Layout.fillWidth: true
        }


        TextArea {
            id: textArea
            text: "Text"
            Layout.minimumHeight: 30
            Layout.minimumWidth: 30
            Layout.columnSpan: 2
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        Button {
            id: addButton
            text: "Add"
        }
    }
}
