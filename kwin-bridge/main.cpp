// macshell-kwin-bridge — the KWin side of MacShell's compositor backend (MacShell/backends/compositor/KWinBackend.qml).
//
// One bridge per MacShell process. It talks to KWin and KDE services only, and speaks newline-delimited JSON with its
// parent (Quickshell) over stdin/stdout; see README.md for the message reference. Everything is event driven: no polling.
//
//   KWin   org_kde_plasma_window_management (KWayland)   windows, active window, state, AppMenu address, window requests
//   KWin   org.kde.KWin.VirtualDesktopManager (D-Bus)     workspaces: list, current, switch
//   apps   com.canonical.dbusmenu (D-Bus)                 the active window's real menu (--global-menu only)
//   kded   org.kde.keyboard /Layouts (D-Bus)              keyboard layouts
//
// Trust boundary: window titles and menu labels only travel through the parent pipe, never to stderr or logs. Commands
// from the parent are validated against current state (known window / desktop / menu item), unknown input is dropped.
// Menu data from applications is untrusted input: depth, size and types are checked while decoding.

#include <KWayland/Client/plasmawindowmanagement.h>
#include <KWayland/Client/registry.h>

#include <QAbstractEventDispatcher>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDateTime>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QSet>
#include <QSocketNotifier>
#include <QTimer>

#include <wayland-client.h>

#include <csignal>
#include <cstdio>
#include <unistd.h>

using KWayland::Client::PlasmaWindow;
using KWayland::Client::PlasmaWindowManagement;
using KWayland::Client::Registry;

namespace
{
constexpr int kProtocol = 1;
constexpr qsizetype kMaxCommandLine = 16 * 1024;
constexpr int kMaxMenuDepth = 12;
constexpr int kMaxMenuItems = 5000;

const QString kKWinService = QStringLiteral("org.kde.KWin");
const QString kDesktopsPath = QStringLiteral("/VirtualDesktopManager");
const QString kDesktopsInterface = QStringLiteral("org.kde.KWin.VirtualDesktopManager");
const QString kPropertiesInterface = QStringLiteral("org.freedesktop.DBus.Properties");
const QString kMenuInterface = QStringLiteral("com.canonical.dbusmenu");
const QString kKeyboardService = QStringLiteral("org.kde.keyboard");
const QString kKeyboardPath = QStringLiteral("/Layouts");
const QString kKeyboardInterface = QStringLiteral("org.kde.KeyboardLayouts");
const QString kMenuViewService = QStringLiteral("org.kde.kappmenuview");
const QString kNotificationsService = QStringLiteral("org.freedesktop.Notifications");
const QString kPlasmaShellService = QStringLiteral("org.kde.plasmashell");
const QString kTrayWatcherService = QStringLiteral("org.kde.StatusNotifierWatcher");

// status codes only: stderr is read by people and log collectors
void logStatus(const char *what)
{
    std::fprintf(stderr, "macshell-kwin-bridge: %s\n", what);
}

QVariant unpackVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<QDBusVariant>()) {
        return value.value<QDBusVariant>().variant();
    }
    return value;
}

// D-BusMenu labels mark the mnemonic with "_" and escape a literal underscore as "__"
QString stripMnemonic(const QString &label)
{
    QString out;
    out.reserve(label.size());
    for (qsizetype i = 0; i < label.size(); ++i) {
        if (label.at(i) == QLatin1Char('_')) {
            if (i + 1 < label.size() && label.at(i + 1) == QLatin1Char('_')) {
                out.append(QLatin1Char('_'));
                ++i;
            }
            continue;
        }
        out.append(label.at(i));
    }
    return out;
}

// "shortcut" is aas, e.g. [["Control","S"]]; anything else is ignored
QJsonArray decodeShortcut(const QVariant &raw)
{
    QJsonArray chords;
    const QVariant value = unpackVariant(raw);
    if (value.metaType() == QMetaType::fromType<QDBusArgument>()) {
        const QDBusArgument argument = value.value<QDBusArgument>();
        // the exact signature, not just "an array": Qt's demarshaller trusts the element types it is asked for
        if (argument.currentSignature() != QLatin1String("aas")) {
            return chords;
        }
        argument.beginArray();
        while (!argument.atEnd() && chords.size() < 4) {
            QStringList keys;
            argument >> keys;
            if (!keys.isEmpty() && keys.size() <= 6) {
                chords.append(QJsonArray::fromStringList(keys));
            }
        }
        argument.endArray();
    } else if (value.canConvert<QVariantList>()) {
        const QVariantList list = value.toList();
        for (const QVariant &chord : list) {
            const QStringList keys = chord.toStringList();
            if (!keys.isEmpty() && keys.size() <= 6 && chords.size() < 4) {
                chords.append(QJsonArray::fromStringList(keys));
            }
        }
    }
    return chords;
}

struct MenuItemInfo {
    bool actionable = false; // may receive "clicked"
    bool submenu = false; // may receive "opened" / "closed" / AboutToShow
};

// one (ia{sv}av) node; returns an empty object for anything malformed. The full signature is checked first: QtDBus
// demarshals by the type it is asked for, and a mismatched element (an app's bug) can crash libdbus, not just fail.
QJsonObject decodeMenuItem(const QDBusArgument &argument, int depth, int &nodes, QHash<int, MenuItemInfo> &index)
{
    if (depth > kMaxMenuDepth || ++nodes > kMaxMenuItems || argument.currentSignature() != QLatin1String("(ia{sv}av)")) {
        return {};
    }

    int id = -1;
    QVariantMap properties;
    QJsonArray children;
    argument.beginStructure();
    argument >> id;
    if (argument.currentType() == QDBusArgument::MapType) {
        argument >> properties;
    }
    if (argument.currentType() == QDBusArgument::ArrayType) {     // av (guaranteed by the signature check)
        argument.beginArray();
        while (!argument.atEnd()) {
            QDBusVariant childVariant;
            argument >> childVariant;
            const QVariant child = childVariant.variant();
            if (child.metaType() == QMetaType::fromType<QDBusArgument>()) {
                const QJsonObject parsed = decodeMenuItem(child.value<QDBusArgument>(), depth + 1, nodes, index);
                if (!parsed.isEmpty()) {
                    children.append(parsed);
                }
            }
        }
        argument.endArray();
    }
    argument.endStructure();
    if (id < 0) {
        return {};
    }

    const auto property = [&properties](const char *name) {
        return unpackVariant(properties.value(QString::fromLatin1(name)));
    };
    const QVariant visibleValue = property("visible");
    const QVariant enabledValue = property("enabled");
    const QVariant toggleStateValue = property("toggle-state");
    const bool visible = visibleValue.isValid() ? visibleValue.toBool() : true;
    const bool enabled = enabledValue.isValid() ? enabledValue.toBool() : true;
    const bool separator = property("type").toString() == QLatin1String("separator");
    const bool submenu = !children.isEmpty() || property("children-display").toString() == QLatin1String("submenu");
    const QString toggleType = property("toggle-type").toString();

    QJsonObject item{
        {QStringLiteral("id"), id},
        {QStringLiteral("label"), stripMnemonic(property("label").toString())},
        {QStringLiteral("visible"), visible},
        {QStringLiteral("enabled"), enabled},
        {QStringLiteral("separator"), separator},
        {QStringLiteral("submenu"), submenu},
        {QStringLiteral("toggle"), (toggleType == QLatin1String("checkmark") || toggleType == QLatin1String("radio")) ? toggleType : QString()},
        // toggle-state: 0 off, 1 on, anything else "indeterminate"
        {QStringLiteral("toggleState"), toggleStateValue.isValid() ? toggleStateValue.toInt() : 0},
        {QStringLiteral("icon"), property("icon-name").toString()},
        {QStringLiteral("shortcut"), decodeShortcut(properties.value(QStringLiteral("shortcut")))},
        {QStringLiteral("children"), children},
    };
    index.insert(id, MenuItemInfo{visible && enabled && !separator && !submenu, visible && enabled && submenu});
    return item;
}

bool isUuidLike(const QString &value)
{
    if (value.isEmpty() || value.size() > 64) {
        return false;
    }
    for (const QChar c : value) {
        if (!(c.isLetterOrNumber() || c == QLatin1Char('-') || c == QLatin1Char('{') || c == QLatin1Char('}'))) {
            return false;
        }
    }
    return true;
}
} // namespace

class Bridge : public QObject
{
    Q_OBJECT

public:
    Bridge(wl_display *display, bool globalMenu, bool checkOnly)
        : m_display(display)
        , m_globalMenu(globalMenu)
        , m_checkOnly(checkOnly)
        , m_bus(QDBusConnection::sessionBus())
    {
        for (QTimer *timer : {&m_windowsTimer, &m_desktopsTimer, &m_menuTimer, &m_keyboardTimer, &m_sessionTimer}) {
            timer->setSingleShot(true);
        }
        m_windowsTimer.setInterval(25); // coalesce bursts (a dragged window moves every frame)
        m_desktopsTimer.setInterval(30);
        m_menuTimer.setInterval(60);
        m_keyboardTimer.setInterval(30);
        m_sessionTimer.setInterval(100);
        connect(&m_windowsTimer, &QTimer::timeout, this, &Bridge::emitWindows);
        connect(&m_desktopsTimer, &QTimer::timeout, this, &Bridge::fetchDesktops);
        connect(&m_menuTimer, &QTimer::timeout, this, &Bridge::fetchMenu);
        connect(&m_keyboardTimer, &QTimer::timeout, this, &Bridge::fetchKeyboard);
        connect(&m_sessionTimer, &QTimer::timeout, this, &Bridge::fetchSession);
    }

    bool start()
    {
        m_registry.create(m_display);
        m_registry.setup();
        if (wl_display_roundtrip(m_display) < 0) {
            logStatus("status=error reason=registry-roundtrip-failed");
            return false;
        }

        m_appMenuProtocol = m_registry.hasInterface(Registry::Interface::AppMenu);
        if (m_registry.hasInterface(Registry::Interface::PlasmaWindowManagement)) {
            const auto global = m_registry.interface(Registry::Interface::PlasmaWindowManagement);
            m_windowManagement = m_registry.createPlasmaWindowManagement(global.name, global.version, this);
            m_advertisedVersion = global.version;
        }
        if (m_windowManagement && m_windowManagement->isValid()) {
            connect(m_windowManagement, &PlasmaWindowManagement::windowCreated, this, &Bridge::trackWindow);
            connect(m_windowManagement, &PlasmaWindowManagement::activeWindowChanged, this, &Bridge::activeWindowChanged);
            connect(m_windowManagement, &PlasmaWindowManagement::stackingOrderUuidsChanged, this, &Bridge::scheduleWindows);
            connect(m_windowManagement, &PlasmaWindowManagement::showingDesktopChanged, this, &Bridge::scheduleWindows);
            connect(m_windowManagement, &PlasmaWindowManagement::removed, this, [] {
                logStatus("status=error reason=window-management-removed");
                QCoreApplication::exit(3);
            });
        } else {
            m_windowManagement = nullptr;
        }

        if (m_bus.isConnected()) {
            watchDesktops();
            watchKeyboard();
            watchSession();
            if (m_globalMenu && !m_checkOnly) {
                // kded only runs the com.canonical.AppMenu.Registrar (which Qt/GTK apps need before they export a menu at
                // all) while some menu view owns org.kde.kappmenuview. Plasma's Global Menu applet registers it the same way,
                // so whichever comes first owns it and the other queues behind it.
                m_bus.interface()->registerService(kMenuViewService,
                                                   QDBusConnectionInterface::QueueService,
                                                   QDBusConnectionInterface::DontAllowReplacement);
            }
        }

        emitHello();
        return true;
    }

    void printCheckSummary()
    {
        int windows = 0;
        for (auto it = m_ready.cbegin(); it != m_ready.cend(); ++it) {
            windows += it.value() ? 1 : 0;
        }
        std::printf("status=ok window_management=%s advertised_version=%u windows=%d active_window_present=%s "
                    "active_window_menu_exported=%s appmenu_protocol_available=%s desktops=%lld current_desktop_known=%s "
                    "keyboard_layouts=%lld plasmashell=%s notifications_owner=%s\n",
                    m_windowManagement ? "available" : "unsupported",
                    m_advertisedVersion,
                    windows,
                    activeReadyWindow() ? "true" : "false",
                    (activeReadyWindow() && !activeReadyWindow()->applicationMenuServiceName().isEmpty()) ? "true" : "false",
                    m_appMenuProtocol ? "true" : "false",
                    static_cast<long long>(m_desktops.size()),
                    m_currentDesktop.isEmpty() ? "false" : "true",
                    static_cast<long long>(m_layouts.size()),
                    m_plasmaShell ? "true" : "false",
                    m_notificationsOwner.toLatin1().constData());
        if (m_globalMenu) {
            // the POC's --menu-check, as counts only: labels, ids and the service/path are never printed
            std::printf("menu_status=%s menu_root_items=%lld menu_items=%lld\n",
                        m_menuStatus.toLatin1().constData(),
                        static_cast<long long>(m_menuItems.size()),
                        static_cast<long long>(m_menuStatus == QLatin1String("ok") ? m_menuIndex.size() - 1 : 0));
        }
        std::fflush(stdout);
    }

    void handleLine(const QByteArray &line)
    {
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(line, &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            return;
        }
        const QJsonObject request = document.object();
        const QString command = request.value(QStringLiteral("cmd")).toString();

        if (command == QLatin1String("setDesktop")) {
            const QString desktop = request.value(QStringLiteral("desktop")).toString();
            if (m_desktopIds.contains(desktop)) {
                QDBusMessage call = QDBusMessage::createMethodCall(kKWinService, kDesktopsPath, kPropertiesInterface, QStringLiteral("Set"));
                call << kDesktopsInterface << QStringLiteral("current") << QVariant::fromValue(QDBusVariant(desktop));
                m_bus.asyncCall(call);
            }
            return;
        }
        if (command == QLatin1String("showDesktop")) {
            if (m_windowManagement) {
                m_windowManagement->setShowingDesktop(request.value(QStringLiteral("on")).toBool());
            }
            return;
        }
        if (command == QLatin1String("setKeyboardLayout")) {
            const int index = request.value(QStringLiteral("index")).toInt(-1);
            if (index >= 0 && index < m_layouts.size()) {
                QDBusMessage call = QDBusMessage::createMethodCall(kKeyboardService, kKeyboardPath, kKeyboardInterface, QStringLiteral("setLayout"));
                call << static_cast<uint>(index);
                m_bus.asyncCall(call);
            }
            return;
        }
        if (command == QLatin1String("menuEvent") || command == QLatin1String("menuAboutToShow")) {
            handleMenuCommand(command, request);
            return;
        }

        PlasmaWindow *window = readyWindow(request.value(QStringLiteral("id")).toString());
        if (!window) {
            return;
        }
        if (command == QLatin1String("activate")) {
            window->requestActivate();
        } else if (command == QLatin1String("close")) {
            if (window->isCloseable()) {
                window->requestClose();
            }
        } else if (command == QLatin1String("minimize")) {
            if (!window->isMinimized() && window->isMinimizeable()) {
                window->requestToggleMinimized();
            }
        } else if (command == QLatin1String("unminimize")) {
            if (window->isMinimized()) {
                window->requestToggleMinimized();
            }
        } else if (command == QLatin1String("toggleMinimize")) {
            if (window->isMinimized() || window->isMinimizeable()) {
                window->requestToggleMinimized();
            }
        } else if (command == QLatin1String("toggleMaximize")) {
            if (window->isMaximizeable()) {
                window->requestToggleMaximized();
            }
        } else if (command == QLatin1String("toggleFullscreen")) {
            if (window->isFullscreenable() || window->isFullscreen()) {
                window->requestToggleFullscreen();
            }
        } else if (command == QLatin1String("toggleKeepAbove")) {
            window->requestToggleKeepAbove();
        } else if (command == QLatin1String("moveToDesktop")) {
            const QString desktop = request.value(QStringLiteral("desktop")).toString();
            if (!m_desktopIds.contains(desktop) || !window->isVirtualDesktopChangeable()) {
                return;
            }
            const QStringList current = window->plasmaVirtualDesktops();
            if (!current.contains(desktop)) {
                window->requestEnterVirtualDesktop(desktop);
            }
            for (const QString &other : current) {
                if (other != desktop) {
                    window->requestLeaveVirtualDesktop(other);
                }
            }
        }
    }

public Q_SLOTS:
    void onDesktopsSignal(const QDBusMessage &)
    {
        m_desktopsTimer.start();
    }
    void onKeyboardSignal(const QDBusMessage &)
    {
        m_keyboardTimer.start();
    }
    void onMenuSignal(const QDBusMessage &)
    {
        // the match rule already limits this to the active menu's sender and path; a late one only causes an extra fetch
        m_menuTimer.start();
    }

private:
    void emitLine(const QJsonObject &object)
    {
        if (m_checkOnly) {
            return;
        }
        const QByteArray json = QJsonDocument(object).toJson(QJsonDocument::Compact);
        if (std::fwrite(json.constData(), 1, json.size(), stdout) != static_cast<size_t>(json.size()) || std::fputc('\n', stdout) == EOF
            || std::fflush(stdout) != 0) {
            QCoreApplication::exit(0); // the parent went away
        }
    }

    void emitHello()
    {
        emitLine({
            {QStringLiteral("type"), QStringLiteral("hello")},
            {QStringLiteral("protocol"), kProtocol},
            {QStringLiteral("bridge"), QStringLiteral(BRIDGE_VERSION)},
            {QStringLiteral("windowManagement"), m_windowManagement ? QStringLiteral("available") : QStringLiteral("unsupported")},
            {QStringLiteral("advertisedVersion"), static_cast<int>(m_advertisedVersion)},
            {QStringLiteral("appMenuProtocol"), m_appMenuProtocol},
            {QStringLiteral("globalMenu"), m_globalMenu && m_windowManagement != nullptr && m_bus.isConnected()},
            {QStringLiteral("dbus"), m_bus.isConnected()},
        });
        if (!m_windowManagement) {
            logStatus("status=unsupported protocol=org_kde_plasma_window_management");
            emitLine({{QStringLiteral("type"), QStringLiteral("windows")},
                      {QStringLiteral("windows"), QJsonArray{}},
                      {QStringLiteral("activeId"), QString()},
                      {QStringLiteral("stacking"), QJsonArray{}},
                      {QStringLiteral("showingDesktop"), false}});
        }
        if (m_globalMenu && !m_windowManagement) {
            emitMenu(QStringLiteral("unsupported"));
        }
    }

    // ── windows ──
    void trackWindow(PlasmaWindow *window)
    {
        const QByteArray uuid = window->uuid();
        m_ready.insert(QString::fromUtf8(uuid), window);
        const auto changed = [this] {
            scheduleWindows();
        };
        for (auto signal : {&PlasmaWindow::titleChanged, &PlasmaWindow::appIdChanged, &PlasmaWindow::activeChanged,
                            &PlasmaWindow::fullscreenChanged, &PlasmaWindow::keepAboveChanged, &PlasmaWindow::minimizedChanged,
                            &PlasmaWindow::maximizedChanged, &PlasmaWindow::onAllDesktopsChanged, &PlasmaWindow::demandsAttentionChanged,
                            &PlasmaWindow::closeableChanged, &PlasmaWindow::minimizeableChanged, &PlasmaWindow::maximizeableChanged,
                            &PlasmaWindow::fullscreenableChanged, &PlasmaWindow::skipTaskbarChanged, &PlasmaWindow::skipSwitcherChanged,
                            &PlasmaWindow::movableChanged, &PlasmaWindow::resizableChanged, &PlasmaWindow::parentWindowChanged,
                            &PlasmaWindow::geometryChanged, &PlasmaWindow::resourceNameChanged}) {
            connect(window, signal, this, changed);
        }
        connect(window, &PlasmaWindow::plasmaVirtualDesktopEntered, this, changed);
        connect(window, &PlasmaWindow::plasmaVirtualDesktopLeft, this, changed);
        connect(window, &PlasmaWindow::applicationMenuChanged, this, [this, window] {
            scheduleWindows();
            if (window == activeReadyWindow()) {
                retargetMenu();
            }
        });
        const QString key = QString::fromUtf8(uuid);
        const auto gone = [this, key] {
            if (m_ready.remove(key) > 0) {
                scheduleWindows();
                retargetMenu();
            }
        };
        connect(window, &PlasmaWindow::unmapped, this, gone);
        connect(window, &QObject::destroyed, this, gone);
        scheduleWindows();
        if (window->isActive()) {
            retargetMenu();
        }
    }

    PlasmaWindow *readyWindow(const QString &id) const
    {
        if (!isUuidLike(id)) {
            return nullptr;
        }
        return m_ready.value(id).data();
    }

    PlasmaWindow *activeReadyWindow() const
    {
        PlasmaWindow *active = m_windowManagement ? m_windowManagement->activeWindow() : nullptr;
        return (active && m_ready.value(QString::fromUtf8(active->uuid())) == active) ? active : nullptr;
    }

    void activeWindowChanged()
    {
        // sent at once, not debounced: the menu that follows must never meet the previous active window in the UI
        m_windowsTimer.stop();
        emitWindows();
        retargetMenu();
    }

    void scheduleWindows()
    {
        if (!m_windowsTimer.isActive()) {
            m_windowsTimer.start();
        }
    }

    void emitWindows()
    {
        QJsonArray windows;
        for (auto it = m_ready.cbegin(); it != m_ready.cend(); ++it) {
            const PlasmaWindow *window = it.value();
            if (!window) {
                continue;
            }
            const QRect geometry = window->geometry();
            const QPointer<PlasmaWindow> parent = window->parentWindow();
            windows.append(QJsonObject{
                {QStringLiteral("id"), it.key()},
                {QStringLiteral("appId"), window->appId()},
                {QStringLiteral("title"), window->title()},
                {QStringLiteral("pid"), static_cast<qint64>(window->pid())},
                {QStringLiteral("resourceName"), window->resourceName()},
                {QStringLiteral("active"), window->isActive()},
                {QStringLiteral("minimized"), window->isMinimized()},
                {QStringLiteral("maximized"), window->isMaximized()},
                {QStringLiteral("fullscreen"), window->isFullscreen()},
                {QStringLiteral("keepAbove"), window->isKeepAbove()},
                {QStringLiteral("onAllDesktops"), window->isOnAllDesktops()},
                {QStringLiteral("demandsAttention"), window->isDemandingAttention()},
                {QStringLiteral("skipTaskbar"), window->skipTaskbar()},
                {QStringLiteral("skipSwitcher"), window->skipSwitcher()},
                {QStringLiteral("closeable"), window->isCloseable()},
                {QStringLiteral("minimizeable"), window->isMinimizeable()},
                {QStringLiteral("maximizeable"), window->isMaximizeable()},
                {QStringLiteral("fullscreenable"), window->isFullscreenable()},
                {QStringLiteral("x"), geometry.x()},
                {QStringLiteral("y"), geometry.y()},
                {QStringLiteral("width"), geometry.width()},
                {QStringLiteral("height"), geometry.height()},
                {QStringLiteral("desktops"), QJsonArray::fromStringList(window->plasmaVirtualDesktops())},
                {QStringLiteral("parent"), parent ? QString::fromUtf8(parent->uuid()) : QString()},
                {QStringLiteral("hasAppMenu"), !window->applicationMenuServiceName().isEmpty() && !window->applicationMenuObjectPath().isEmpty()},
            });
        }

        QJsonArray stacking;
        if (m_windowManagement) {
            for (const QByteArray &uuid : m_windowManagement->stackingOrderUuids()) {
                if (m_ready.contains(QString::fromUtf8(uuid))) {
                    stacking.append(QString::fromUtf8(uuid));
                }
            }
        }
        const PlasmaWindow *active = activeReadyWindow();
        const QJsonObject message{
            {QStringLiteral("type"), QStringLiteral("windows")},
            {QStringLiteral("windows"), windows},
            {QStringLiteral("activeId"), active ? QString::fromUtf8(active->uuid()) : QString()},
            {QStringLiteral("stacking"), stacking},
            {QStringLiteral("showingDesktop"), m_windowManagement && m_windowManagement->isShowingDesktop()},
        };
        const QByteArray json = QJsonDocument(message).toJson(QJsonDocument::Compact);
        if (json != m_lastWindowsJson) {
            m_lastWindowsJson = json;
            emitLine(message);
        }
    }

    // ── workspaces (KWin virtual desktops over D-Bus) ──
    void watchDesktops()
    {
        for (const char *signal : {"currentChanged", "countChanged", "rowsChanged", "desktopsChanged", "desktopCreated", "desktopRemoved",
                                   "desktopDataChanged"}) {
            m_bus.connect(kKWinService, kDesktopsPath, kDesktopsInterface, QString::fromLatin1(signal), this, SLOT(onDesktopsSignal(QDBusMessage)));
        }
        auto *watcher = new QDBusServiceWatcher(kKWinService, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
            m_desktopsTimer.start();
        });
        fetchDesktops();
    }

    void fetchDesktops()
    {
        QDBusMessage call = QDBusMessage::createMethodCall(kKWinService, kDesktopsPath, kPropertiesInterface, QStringLiteral("GetAll"));
        call << kDesktopsInterface;
        auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(call), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *self) {
            self->deleteLater();
            const QDBusMessage reply = self->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
                m_desktops = {};
                m_desktopIds.clear();
                m_currentDesktop.clear();
                emitDesktops(false);
                return;
            }
            const QVariantMap properties = qdbus_cast<QVariantMap>(reply.arguments().constFirst());
            QJsonArray desktops;
            QSet<QString> ids;
            const QVariant raw = unpackVariant(properties.value(QStringLiteral("desktops")));
            if (raw.metaType() == QMetaType::fromType<QDBusArgument>()) {
                const QDBusArgument argument = raw.value<QDBusArgument>();
                if (argument.currentSignature() == QLatin1String("a(uss)")) {
                    argument.beginArray();
                    while (!argument.atEnd() && desktops.size() < 64) {
                        uint position = 0;
                        QString id;
                        QString name;
                        argument.beginStructure();
                        argument >> position >> id >> name;
                        argument.endStructure();
                        if (!id.isEmpty()) {
                            ids.insert(id);
                            desktops.append(QJsonObject{{QStringLiteral("id"), id},
                                                        {QStringLiteral("name"), name},
                                                        {QStringLiteral("position"), static_cast<int>(position)}});
                        }
                    }
                    argument.endArray();
                }
            }
            m_desktops = desktops;
            m_desktopIds = ids;
            m_currentDesktop = unpackVariant(properties.value(QStringLiteral("current"))).toString();
            m_desktopRows = unpackVariant(properties.value(QStringLiteral("rows"))).toUInt();
            emitDesktops(true);
        });
    }

    void emitDesktops(bool available)
    {
        emitLine({{QStringLiteral("type"), QStringLiteral("workspaces")},
                  {QStringLiteral("available"), available},
                  {QStringLiteral("current"), m_currentDesktop},
                  {QStringLiteral("rows"), static_cast<int>(m_desktopRows)},
                  {QStringLiteral("desktops"), m_desktops}});
    }

    // ── keyboard layouts (KDE keyboard daemon) ──
    void watchKeyboard()
    {
        for (const char *signal : {"layoutChanged", "layoutListChanged"}) {
            m_bus.connect(kKeyboardService, kKeyboardPath, kKeyboardInterface, QString::fromLatin1(signal), this, SLOT(onKeyboardSignal(QDBusMessage)));
        }
        auto *watcher = new QDBusServiceWatcher(kKeyboardService, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
            m_keyboardTimer.start();
        });
        fetchKeyboard();
    }

    void fetchKeyboard()
    {
        const QDBusMessage listCall = QDBusMessage::createMethodCall(kKeyboardService, kKeyboardPath, kKeyboardInterface, QStringLiteral("getLayoutsList"));
        auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(listCall), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *self) {
            self->deleteLater();
            const QDBusMessage reply = self->reply();
            QJsonArray layouts;
            if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()
                && reply.arguments().constFirst().metaType() == QMetaType::fromType<QDBusArgument>()) {
                // a(sss): short name, display name, long name (KWin keyboard_layout.h LayoutNames)
                const QDBusArgument argument = reply.arguments().constFirst().value<QDBusArgument>();
                if (argument.currentSignature() == QLatin1String("a(sss)")) {
                    argument.beginArray();
                    while (!argument.atEnd() && layouts.size() < 32) {
                        QString shortName;
                        QString displayName;
                        QString longName;
                        argument.beginStructure();
                        argument >> shortName >> displayName >> longName;
                        argument.endStructure();
                        layouts.append(QJsonObject{{QStringLiteral("short"), shortName},
                                                   {QStringLiteral("display"), displayName},
                                                   {QStringLiteral("name"), longName}});
                    }
                    argument.endArray();
                }
            }
            m_layouts = layouts;
            const QDBusMessage currentCall = QDBusMessage::createMethodCall(kKeyboardService, kKeyboardPath, kKeyboardInterface, QStringLiteral("getLayout"));
            auto *current = new QDBusPendingCallWatcher(m_bus.asyncCall(currentCall), this);
            connect(current, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *self) {
                self->deleteLater();
                const QDBusPendingReply<uint> reply = *self;
                emitLine({{QStringLiteral("type"), QStringLiteral("keyboard")},
                          {QStringLiteral("available"), !m_layouts.isEmpty()},
                          {QStringLiteral("current"), reply.isValid() ? static_cast<int>(reply.value()) : -1},
                          {QStringLiteral("layouts"), m_layouts}});
            });
        });
    }

    // ── session services: who owns what (so MacShell never starts a duplicate daemon) ──
    void watchSession()
    {
        for (const QString &service : {kPlasmaShellService, kNotificationsService, kTrayWatcherService, kMenuViewService}) {
            auto *watcher = new QDBusServiceWatcher(service, m_bus, QDBusServiceWatcher::WatchForOwnerChange, this);
            connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
                m_sessionTimer.start();
            });
        }
        fetchSession();
    }

    // "none" | "self" (our parent, i.e. this MacShell) | "bridge" (this process) | "other"
    QString ownerOf(const QString &service) const
    {
        QDBusConnectionInterface *bus = m_bus.interface();
        const QDBusReply<QString> owner = bus->serviceOwner(service);
        if (!owner.isValid() || owner.value().isEmpty()) {
            return QStringLiteral("none");
        }
        if (owner.value() == m_bus.baseService()) {
            return QStringLiteral("bridge");
        }
        const QDBusReply<uint> pid = bus->servicePid(owner.value());
        if (pid.isValid() && static_cast<pid_t>(pid.value()) == getppid()) {
            return QStringLiteral("self");
        }
        return QStringLiteral("other");
    }

    void fetchSession()
    {
        m_plasmaShell = m_bus.interface()->isServiceRegistered(kPlasmaShellService).value();
        m_notificationsOwner = ownerOf(kNotificationsService);
        emitLine({{QStringLiteral("type"), QStringLiteral("session")},
                  {QStringLiteral("plasmashell"), m_plasmaShell},
                  {QStringLiteral("notifications"), m_notificationsOwner},
                  {QStringLiteral("trayWatcher"), ownerOf(kTrayWatcherService)},
                  {QStringLiteral("menuView"), ownerOf(kMenuViewService)}});
    }

    // ── global menu (the active window's com.canonical.dbusmenu tree) ──
    void retargetMenu()
    {
        if (!m_globalMenu || !m_windowManagement) {
            return;
        }
        PlasmaWindow *window = activeReadyWindow();
        const QString windowId = window ? QString::fromUtf8(window->uuid()) : QString();
        const QString service = window ? window->applicationMenuServiceName() : QString();
        const QString path = window ? window->applicationMenuObjectPath() : QString();
        if (windowId == m_menuWindow && service == m_menuService && path == m_menuPath) {
            return;
        }
        if (!m_menuService.isEmpty()) {
            for (const char *signal : {"LayoutUpdated", "ItemsPropertiesUpdated"}) {
                m_bus.disconnect(m_menuService, m_menuPath, kMenuInterface, QString::fromLatin1(signal), this, SLOT(onMenuSignal(QDBusMessage)));
            }
        }
        m_menuWindow = windowId;
        m_menuAppId = window ? window->appId() : QString();
        m_menuService = service;
        m_menuPath = path;
        m_menuItems = {};
        m_menuIndex.clear();
        ++m_menuGeneration;
        m_menuTimer.stop();
        if (service.isEmpty() || path.isEmpty()) {
            emitMenu(QStringLiteral("none"));
            return;
        }
        for (const char *signal : {"LayoutUpdated", "ItemsPropertiesUpdated"}) {
            m_bus.connect(service, path, kMenuInterface, QString::fromLatin1(signal), this, SLOT(onMenuSignal(QDBusMessage)));
        }
        emitMenu(QStringLiteral("loading"));
        fetchMenu();
    }

    void fetchMenu()
    {
        if (m_menuService.isEmpty()) {
            return;
        }
        QDBusMessage call = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuInterface, QStringLiteral("GetLayout"));
        call << 0 << -1 << QStringList{};
        const quint64 generation = m_menuGeneration;
        auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(call, 3000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
            self->deleteLater();
            if (generation != m_menuGeneration) {
                return; // the active window changed while this was in flight
            }
            const QDBusMessage reply = self->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.signature() != QLatin1String("u(ia{sv}av)")
                || reply.arguments().size() != 2 || reply.arguments().at(1).metaType() != QMetaType::fromType<QDBusArgument>()) {
                m_menuItems = {};
                m_menuIndex.clear();
                emitMenu(QStringLiteral("error"));
                return;
            }
            QHash<int, MenuItemInfo> index;
            int nodes = 0;
            const QJsonObject root = decodeMenuItem(reply.arguments().at(1).value<QDBusArgument>(), 0, nodes, index);
            m_menuItems = root.value(QStringLiteral("children")).toArray();
            m_menuIndex = index;
            m_menuIndex.insert(0, MenuItemInfo{false, true});
            m_menuRevision = reply.arguments().at(0).toUInt();
            emitMenu(QStringLiteral("ok"));
        });
    }

    void emitMenu(const QString &status)
    {
        m_menuStatus = status;
        emitLine({{QStringLiteral("type"), QStringLiteral("menu")},
                  {QStringLiteral("status"), status},
                  {QStringLiteral("windowId"), m_menuWindow},
                  {QStringLiteral("appId"), m_menuAppId},
                  {QStringLiteral("revision"), static_cast<qint64>(m_menuRevision)},
                  {QStringLiteral("items"), status == QLatin1String("ok") ? m_menuItems : QJsonArray{}}});
    }

    void handleMenuCommand(const QString &command, const QJsonObject &request)
    {
        // the request must name the window whose menu is showing, and that window must still be active with the same address
        PlasmaWindow *active = activeReadyWindow();
        const QString windowId = request.value(QStringLiteral("windowId")).toString();
        const int itemId = request.value(QStringLiteral("id")).toInt(-1);
        if (!active || m_menuService.isEmpty() || windowId != m_menuWindow || QString::fromUtf8(active->uuid()) != m_menuWindow
            || active->applicationMenuServiceName() != m_menuService || active->applicationMenuObjectPath() != m_menuPath
            || !m_menuIndex.contains(itemId)) {
            return;
        }
        const MenuItemInfo info = m_menuIndex.value(itemId);

        if (command == QLatin1String("menuAboutToShow")) {
            if (!info.submenu) {
                return;
            }
            QDBusMessage call = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuInterface, QStringLiteral("AboutToShow"));
            call << itemId;
            const quint64 generation = m_menuGeneration;
            auto *watcher = new QDBusPendingCallWatcher(m_bus.asyncCall(call, 1000), this);
            connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, generation](QDBusPendingCallWatcher *self) {
                self->deleteLater();
                const QDBusPendingReply<bool> reply = *self;
                if (generation == m_menuGeneration && reply.isValid() && reply.value()) {
                    m_menuTimer.start();
                }
            });
            return;
        }

        const QString event = request.value(QStringLiteral("event")).toString();
        const bool allowed = (event == QLatin1String("clicked") && info.actionable)
            || ((event == QLatin1String("opened") || event == QLatin1String("closed")) && info.submenu);
        if (!allowed) {
            return;
        }
        QDBusMessage call = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuInterface, QStringLiteral("Event"));
        call << itemId << event << QVariant::fromValue(QDBusVariant(QString())) << 0u; // as KDE's DBusMenuImporter sends it
        m_bus.asyncCall(call, 1000);
    }

    wl_display *m_display;
    const bool m_globalMenu;
    const bool m_checkOnly;
    QDBusConnection m_bus;
    Registry m_registry;
    PlasmaWindowManagement *m_windowManagement = nullptr;
    quint32 m_advertisedVersion = 0;
    bool m_appMenuProtocol = false;

    QHash<QString, QPointer<PlasmaWindow>> m_ready; // windows past their initial state, by uuid
    QByteArray m_lastWindowsJson;
    QTimer m_windowsTimer;

    QJsonArray m_desktops;
    QSet<QString> m_desktopIds;
    QString m_currentDesktop;
    uint m_desktopRows = 1;
    QTimer m_desktopsTimer;

    QJsonArray m_layouts;
    QTimer m_keyboardTimer;

    bool m_plasmaShell = false;
    QString m_notificationsOwner = QStringLiteral("none");
    QTimer m_sessionTimer;

    QString m_menuWindow;
    QString m_menuAppId;
    QString m_menuService;
    QString m_menuPath;
    QJsonArray m_menuItems;
    QHash<int, MenuItemInfo> m_menuIndex;
    QString m_menuStatus = QStringLiteral("none");
    quint64 m_menuGeneration = 0;
    uint m_menuRevision = 0;
    QTimer m_menuTimer;
};

int main(int argc, char **argv)
{
    // The bridge never shows a window: the offscreen platform keeps Qt from opening a second Wayland connection or
    // initialising EGL (on hybrid laptops an EGL init can wake the discrete GPU). KWayland needs a QGuiApplication for icons.
    qputenv("QT_QPA_PLATFORM", "offscreen");
    std::signal(SIGPIPE, SIG_IGN);
    QGuiApplication app(argc, argv);

    bool globalMenu = false;
    bool checkOnly = false;
    for (int i = 1; i < argc; ++i) {
        const QByteArray argument(argv[i]);
        if (argument == "--global-menu") {
            globalMenu = true;
        } else if (argument == "--check") {
            checkOnly = true;
        } else if (argument == "--version") {
            std::printf("macshell-kwin-bridge %s (protocol %d)\n", BRIDGE_VERSION, kProtocol);
            return 0;
        } else {
            logStatus("usage: macshell-kwin-bridge [--global-menu] [--check] [--version]");
            return 2;
        }
    }

    wl_display *display = wl_display_connect(nullptr);
    if (!display) {
        logStatus("status=error reason=wayland-connect-failed");
        return 2;
    }

    // Wayland events are read and dispatched from Qt's event loop; requests are flushed before it sleeps.
    QSocketNotifier waylandNotifier(wl_display_get_fd(display), QSocketNotifier::Read);
    const auto waylandFailed = [&waylandNotifier] {
        logStatus("status=error reason=wayland-connection-lost");
        waylandNotifier.setEnabled(false);
        QCoreApplication::exit(3);
    };
    QObject::connect(&waylandNotifier, &QSocketNotifier::activated, &app, [display, waylandFailed] {
        if (wl_display_prepare_read(display) == 0 && wl_display_read_events(display) < 0) {
            waylandFailed();
            return;
        }
        if (wl_display_dispatch_pending(display) < 0) {
            waylandFailed();
        }
    });
    QObject::connect(QAbstractEventDispatcher::instance(), &QAbstractEventDispatcher::aboutToBlock, &app, [display, waylandFailed] {
        if (wl_display_dispatch_pending(display) < 0) {
            waylandFailed();
            return;
        }
        wl_display_flush(display);
    });

    int result = 0;
    {
        Bridge bridge(display, globalMenu, checkOnly);
        if (!bridge.start()) {
            result = 2;
        } else if (checkOnly) {
            // one sanitized summary line (counts and states only), after the initial window states and D-Bus replies arrive
            QTimer::singleShot(1500, &app, [&bridge] {
                bridge.printCheckSummary();
                QCoreApplication::exit(0);
            });
            result = app.exec();
        } else {
            QByteArray input;
            QSocketNotifier stdinNotifier(STDIN_FILENO, QSocketNotifier::Read);
            QObject::connect(&stdinNotifier, &QSocketNotifier::activated, &app, [&] {
                char buffer[4096];
                const ssize_t count = ::read(STDIN_FILENO, buffer, sizeof(buffer));
                if (count <= 0) {
                    QCoreApplication::exit(0); // the parent closed the pipe: MacShell is gone
                    return;
                }
                input.append(buffer, count);
                qsizetype newline;
                while ((newline = input.indexOf('\n')) >= 0) {
                    const QByteArray line = input.left(newline);
                    input.remove(0, newline + 1);
                    if (line.size() <= kMaxCommandLine) {
                        bridge.handleLine(line);
                    }
                }
                if (input.size() > kMaxCommandLine) {
                    input.clear(); // an unterminated oversized line is dropped
                }
            });
            result = app.exec();
        }
    }
    wl_display_disconnect(display);
    return result;
}

#include "main.moc"
