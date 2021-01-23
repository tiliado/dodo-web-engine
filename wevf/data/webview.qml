import QtWebEngine 1.10
import eu.tiliado.NuvolaPlayer 1.0

WebEngineView {
    focus: true
    property Component component: null
    property Canvas canvas: null

    onNewViewRequested: function (request) {
        request.openIn(component.createRelated(canvas));
    }

    onContextMenuRequested: function (request) {
        request.accepted = true;
    }
}
