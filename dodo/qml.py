from PySide2.QtCore import QTimer, Slot, Signal, QObject, QUrl
from PySide2.QtQml import QQmlComponent, QQmlIncubationController, QQmlEngine, qmlRegisterType
from PySide2.QtQuick import QQuickItem

from dodo.view import View


class IncubationController(QQmlIncubationController):
    def __init__(self):
        super().__init__()
        self._timer = timer = QTimer()
        timer.setSingleShot(False)
        timer.setInterval(10)
        timer.timeout.connect(self._onTimer)
        timer.start()

    @Slot()
    def _onTimer(self):
        self.incubateFor(5)


class Engine(QObject):
    def __init__(self):
        super().__init__()
        self.engine = QQmlEngine()
        self.incubation = IncubationController()
        self.engine.setIncubationController(self.incubation)


class Component(QObject):
    relatedCreated = Signal((View, QQuickItem,))

    def __init__(self, engine: Engine, qmlUrl: QUrl):
        super().__init__()
        self.engine = engine
        self.qmlUrl = qmlUrl
        self.component = None

    def load(self):
        self.component = component = QQmlComponent(self.engine.engine, self.qmlUrl, QQmlComponent.PreferSynchronous)
        assert not component.isLoading()
        if component.isError():
            for err in component.errors():
                print("Error:", err.url(), err.line(), err)

    @Slot(View, result=QObject)
    def createRelated(self, view):
        item = self.create()
        self.relatedCreated.emit(view, item)
        return item

    def create(self):
        component = self.component
        item = self.component.create()
        if component.isError():
            for err in component.errors():
                print("Error:", err.url(), err.line(), err)
            return None

        if not isinstance(item, QQuickItem):
            raise TypeError(f'Unexpected QML type {type(item)}.')

        item.setProperty("component", self)
        return item

qmlRegisterType(Component, "eu.tiliado.NuvolaPlayer", 1, 0, "Component")
qmlRegisterType(View, "eu.tiliado.NuvolaPlayer", 1, 0, "Canvas")
