import QtWebEngine 1.10

WebEngineView {
    focus: true
    url: "https://www.seznam.cz"

    onNewViewRequested: function (request) {
        request.openIn(this);
    }

    onContextMenuRequested: function (request) {
        request.accepted = true;
    }
}
