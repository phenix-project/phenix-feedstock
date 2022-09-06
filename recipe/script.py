import sys
import os

from PySide2 import QtCore, QtWidgets, QtDesigner
a = __import__(sys.argv[1], fromlist=[sys.argv[2]])

def dump_ui(widget, path):
    builder = QtDesigner.QFormBuilder()
    stream = QtCore.QFile(path)
    stream.open(QtCore.QIODevice.WriteOnly)
    builder.save(stream, widget)
    stream.close()

app = QtGui.QApplication([''])

if sys.argv[3] == "dialog":
	dialog = QtWidgets.QDialog()
	a().setupUi(dialog)

	dialog.show()
else:
	window = QtWidgets.MainWindow()
	a().setupUi(window)

	window.show()

dump_ui(dialog, 'myui.ui')
