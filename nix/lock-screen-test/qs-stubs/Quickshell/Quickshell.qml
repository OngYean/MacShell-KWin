pragma Singleton
import QtQuick

QtObject {
    function env(name) { return name === "HOME" ? "/home/test" : ""; }
    function execDetached(argv) { }
}
