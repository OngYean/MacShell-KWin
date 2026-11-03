#include "menu-label.h"

#include <KWayland/Client/plasmawindowmanagement.h>
#include <KWayland/Client/registry.h>

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDateTime>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusVariant>
#include <QEventLoop>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QTimer>

#include <wayland-client.h>

#include <iostream>
#include <memory>
#include <unistd.h>

using KWayland::Client::PlasmaWindow;
using KWayland::Client::PlasmaWindowManagement;
using KWayland::Client::Registry;

namespace
{
int fail(const char *reason, wl_display *display = nullptr)
{
    std::cerr << "status=error reason=" << reason;
    if (display) {
        std::cerr << " wayland_error=" << wl_display_get_error(display);
    }
    std::cerr << '\n';
    return 2;
}

QVariant unpackDbusVariant(const QVariant &value)
{
    if (value.metaType().id() == qMetaTypeId<QDBusVariant>()) {
        return value.value<QDBusVariant>().variant();
    }
    return value;
}

QJsonObject dbusMenuItem(const QDBusArgument &argument)
{
    if (argument.currentType() != QDBusArgument::StructureType) {
        return {};
    }

    argument.beginStructure();
    int id = 0;
    QVariantMap properties;
    argument >> id >> properties;

    QJsonArray childItems;
    argument.beginArray();
    while (!argument.atEnd()) {
        QDBusVariant childVariant;
        argument >> childVariant;
        const QVariant child = childVariant.variant();
        if (child.metaType().id() == qMetaTypeId<QDBusArgument>()) {
            const QJsonObject parsedChild = dbusMenuItem(child.value<QDBusArgument>());
            if (!parsedChild.isEmpty()) {
                childItems.append(parsedChild);
            }
        }
    }
    argument.endArray();
    argument.endStructure();

    const QString itemType = unpackDbusVariant(properties.value("type")).toString();
    const QString toggleType = unpackDbusVariant(properties.value("toggle-type")).toString();
    const QVariant toggleState = unpackDbusVariant(properties.value("toggle-state"));

    const QVariant visibleValue = unpackDbusVariant(properties.value("visible"));
    const QVariant enabledValue = unpackDbusVariant(properties.value("enabled"));
    return {
        {"id", id},
        {"label", displayDbusMenuLabel(unpackDbusVariant(properties.value("label")).toString())},
        {"visible", visibleValue.isValid() ? visibleValue.toBool() : true},
        {"enabled", enabledValue.isValid() ? enabledValue.toBool() : true},
        {"separator", itemType == "separator"},
        {"toggleType", toggleType},
        {"checked", toggleState.toInt() != 0},
        {"children", childItems},
    };
}

QJsonArray dbusMenuLayoutItems(const QDBusMessage &reply)
{
    if (reply.arguments().size() != 2
        || reply.arguments().at(1).metaType().id() != qMetaTypeId<QDBusArgument>()) {
        return {};
    }

    const QJsonObject root = dbusMenuItem(reply.arguments().at(1).value<QDBusArgument>());
    return root.value("children").toArray();
}

QJsonObject findDbusMenuItem(const QJsonArray &items, int id)
{
    for (const QJsonValue &value : items) {
        const QJsonObject item = value.toObject();
        if (item.value("id").toInt(-1) == id) {
            return item;
        }
        const QJsonObject nested = findDbusMenuItem(item.value("children").toArray(), id);
        if (!nested.isEmpty()) {
            return nested;
        }
    }
    return {};
}

bool sendDbusMenuEvent(const QString &service, const QString &path, int id, const QString &eventName)
{
    QDBusMessage request = QDBusMessage::createMethodCall(
        service,
        path,
        "com.canonical.dbusmenu",
        "Event");
    request.setArguments({
        id,
        eventName,
        QVariant::fromValue(QDBusVariant(QVariant(0))),
        static_cast<uint>(QDateTime::currentMSecsSinceEpoch()),
    });
    const QDBusMessage reply = QDBusConnection::sessionBus().call(request, QDBus::Block, 1000);
    return reply.type() == QDBusMessage::ReplyMessage;
}

QString dbusMenuLayoutStatus(const PlasmaWindow *window, int *rootItemCount = nullptr, QJsonArray *menuItems = nullptr)
{
    if (rootItemCount) {
        *rootItemCount = -1;
    }
    if (menuItems) {
        *menuItems = {};
    }
    if (!window || window->applicationMenuServiceName().isEmpty() || window->applicationMenuObjectPath().isEmpty()) {
        return "no-active-address";
    }

    QDBusMessage request = QDBusMessage::createMethodCall(
        window->applicationMenuServiceName(),
        window->applicationMenuObjectPath(),
        "com.canonical.dbusmenu",
        "GetLayout");
    request.setArguments({0, -1, QStringList{}});
    const QDBusMessage reply = QDBusConnection::sessionBus().call(request, QDBus::Block, 3000);
    if (reply.type() != QDBusMessage::ReplyMessage) {
        return "call-failed";
    }
    if (reply.arguments().size() != 2) {
        return "invalid-reply";
    }
    const QJsonArray items = dbusMenuLayoutItems(reply);
    if (rootItemCount) {
        *rootItemCount = items.size();
    }
    if (menuItems) {
        *menuItems = items;
    }
    return "layout-retrieved";
}

QJsonObject windowData(const PlasmaWindow *window)
{
    const QRect geometry = window->geometry();
    QJsonObject result;
    result.insert("id", QString::fromUtf8(window->uuid()));
    result.insert("title", window->title());
    result.insert("appId", window->appId());
    result.insert("active", window->isActive());
    result.insert("minimized", window->isMinimized());
    result.insert("maximized", window->isMaximized());
    result.insert("fullscreen", window->isFullscreen());
    result.insert("closeable", window->isCloseable());
    result.insert("minimizeable", window->isMinimizeable());
    result.insert("maximizeable", window->isMaximizeable());
    result.insert("geometry", QJsonObject{
        {"x", geometry.x()},
        {"y", geometry.y()},
        {"width", geometry.width()},
        {"height", geometry.height()},
    });
    result.insert("desktopIds", QJsonArray::fromStringList(window->plasmaVirtualDesktops()));
    result.insert("menuService", window->applicationMenuServiceName());
    result.insert("menuPath", window->applicationMenuObjectPath());
    return result;
}
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    const QByteArray argument = argc == 2 ? QByteArray(argv[1]) : QByteArray();
    const bool watchMode = argument == "--watch";
    const bool menuCheckMode = argument == "--menu-check";
    const bool menuWatchMode = argument == "--menu-watch";
    if (argc > 2 || (argc == 2 && !watchMode && !menuCheckMode && !menuWatchMode)) {
        return fail("usage: macshell-kwin-backend-probe [--watch|--menu-check|--menu-watch]");
    }

    wl_display *display = wl_display_connect(nullptr);
    if (!display) {
        return fail("wayland-connect-failed");
    }

    int result = 0;
    auto registry = std::make_unique<Registry>();
    registry->create(display);
    registry->setup();
    if (wl_display_roundtrip(display) < 0) {
        result = fail("registry-roundtrip-failed", display);
    } else if (!registry->hasInterface(Registry::Interface::PlasmaWindowManagement)) {
        if (watchMode) {
            std::cout << "{\"status\":\"unsupported\",\"protocol\":\"org_kde_plasma_window_management\"}\n";
        } else {
            std::cout << "status=unsupported protocol=org_kde_plasma_window_management\n";
        }
    } else {
        const auto global = registry->interface(Registry::Interface::PlasmaWindowManagement);
        auto management = std::unique_ptr<PlasmaWindowManagement>(
            registry->createPlasmaWindowManagement(global.name, global.version));

        if (!management || !management->isValid()) {
            result = fail("window-management-bind-failed", display);
        } else {
            bool roundtripFailed = false;
            for (int i = 0; i < 8; ++i) {
                if (wl_display_roundtrip(display) < 0) {
                    roundtripFailed = true;
                    break;
                }
                QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
            }

            if (roundtripFailed) {
                result = fail("window-state-roundtrip-failed", display);
            } else {
                QDBusInterface kwin("org.kde.KWin", "/KWin", "org.kde.KWin");
                QDBusInterface virtualDesktops(
                    "org.kde.KWin",
                    "/VirtualDesktopManager",
                    "org.kde.KWin.VirtualDesktopManager");
                const bool appMenuProtocolAvailable = registry->hasInterface(Registry::Interface::AppMenu);

                const auto snapshot = [&]() {
                    QJsonObject root;
                    QJsonArray windows;
                    PlasmaWindow *active = management->activeWindow();
                    for (PlasmaWindow *window : management->windows()) {
                        windows.append(windowData(window));
                    }

                    root.insert("status", "ok");
                    root.insert("protocol", "org_kde_plasma_window_management");
                    root.insert("protocolVersion", static_cast<int>(global.version));
                    root.insert("appMenuProtocolAvailable", appMenuProtocolAvailable);
                    root.insert("windows", windows);
                    root.insert("activeWindowId", active ? QString::fromUtf8(active->uuid()) : QString());
                    root.insert("activeWindowMenuExported", active
                        && !active->applicationMenuServiceName().isEmpty()
                        && !active->applicationMenuObjectPath().isEmpty());

                    QJsonObject capabilities;
                    capabilities.insert("windowEnumeration", "available");
                    capabilities.insert("activeWindowTracking", "available");
                    capabilities.insert("appMenuRegistration", appMenuProtocolAvailable ? "available" : "unavailable");
                    capabilities.insert("workspaceRead", virtualDesktops.isValid() ? "available" : "unavailable");
                    capabilities.insert("activation", "not-implemented");
                    capabilities.insert("windowCapture", "unsupported");
                    capabilities.insert("globalMenu", "address-only");
                    root.insert("capabilities", capabilities);

                    QJsonObject workspaces;
                    const QDBusReply<int> currentNumber = kwin.call("currentDesktop");
                    const QVariant currentId = virtualDesktops.property("current");
                    const QVariant count = virtualDesktops.property("count");
                    const bool workspaceAvailable = virtualDesktops.isValid()
                        && currentNumber.isValid()
                        && currentId.isValid()
                        && count.isValid();
                    workspaces.insert("available", workspaceAvailable);
                    if (workspaceAvailable) {
                        workspaces.insert("currentIndex", currentNumber.value());
                        workspaces.insert("currentId", currentId.toString());
                        workspaces.insert("count", static_cast<int>(count.toUInt()));
                    }
                    root.insert("workspaces", workspaces);
                    return root;
                };

                QString currentMenuWindowId;
                QString currentMenuService;
                QString currentMenuPath;
                QJsonArray currentMenuItems;
                const auto menuSnapshot = [&]() {
                    QJsonObject root;
                    PlasmaWindow *active = management->activeWindow();
                    const QString nextWindowId = active ? QString::fromUtf8(active->uuid()) : QString();
                    const QString nextService = active ? active->applicationMenuServiceName() : QString();
                    const QString nextPath = active ? active->applicationMenuObjectPath() : QString();
                    if (nextWindowId != currentMenuWindowId || nextService != currentMenuService || nextPath != currentMenuPath) {
                        currentMenuItems = {};
                    }
                    currentMenuWindowId = nextWindowId;
                    currentMenuService = nextService;
                    currentMenuPath = nextPath;

                    QJsonArray menuItems;
                    int rootItemCount = -1;
                    const QString layoutStatus = dbusMenuLayoutStatus(active, &rootItemCount, &menuItems);
                    currentMenuItems = layoutStatus == "layout-retrieved" ? menuItems : QJsonArray{};
                    const bool menuExported = active
                        && !active->applicationMenuServiceName().isEmpty()
                        && !active->applicationMenuObjectPath().isEmpty();
                    root.insert("status", "ok");
                    root.insert("activeWindowId", currentMenuWindowId);
                    root.insert("activeAppId", active ? active->appId() : QString());
                    root.insert("activeWindowMenuExported", menuExported);
                    root.insert("menuStatus", layoutStatus);
                    root.insert("menuRootItemCount", rootItemCount);
                    root.insert("menuItems", menuItems);
                    return root;
                };

                const QJsonObject initial = snapshot();
                if (watchMode || menuWatchMode) {
                    const auto currentSnapshot = [&]() {
                        return menuWatchMode ? menuSnapshot() : snapshot();
                    };
                    QByteArray lastJson = QJsonDocument(menuWatchMode ? menuSnapshot() : initial).toJson(QJsonDocument::Compact);
                    std::cout << lastJson.constData() << '\n' << std::flush;

                    QByteArray inputBuffer;
                    std::unique_ptr<QSocketNotifier> stdinNotifier;
                    if (menuWatchMode) {
                        stdinNotifier = std::make_unique<QSocketNotifier>(STDIN_FILENO, QSocketNotifier::Read, &app);
                        QObject::connect(stdinNotifier.get(), &QSocketNotifier::activated, &app, [&]() {
                            char buffer[4096];
                            const ssize_t bytesRead = ::read(STDIN_FILENO, buffer, sizeof(buffer));
                            if (bytesRead <= 0) {
                                stdinNotifier->setEnabled(false);
                                return;
                            }
                            inputBuffer.append(buffer, static_cast<qsizetype>(bytesRead));
                            qsizetype newline = -1;
                            while ((newline = inputBuffer.indexOf('\n')) >= 0) {
                                const QByteArray line = inputBuffer.left(newline);
                                inputBuffer.remove(0, newline + 1);
                                QJsonParseError parseError;
                                const QJsonDocument command = QJsonDocument::fromJson(line, &parseError);
                                if (parseError.error != QJsonParseError::NoError || !command.isObject()) {
                                    continue;
                                }

                                const QJsonObject request = command.object();
                                const QString eventName = request.value("action").toString();
                                const int itemId = request.value("id").toInt(-1);
                                if (itemId < 0 || (eventName != "opened" && eventName != "closed" && eventName != "clicked")) {
                                    continue;
                                }

                                PlasmaWindow *active = management->activeWindow();
                                if (!active
                                    || QString::fromUtf8(active->uuid()) != currentMenuWindowId
                                    || active->applicationMenuServiceName() != currentMenuService
                                    || active->applicationMenuObjectPath() != currentMenuPath) {
                                    continue;
                                }
                                const QJsonObject item = findDbusMenuItem(currentMenuItems, itemId);
                                if (item.isEmpty()
                                    || !item.value("visible").toBool(true)
                                    || !item.value("enabled").toBool(true)
                                    || item.value("separator").toBool()) {
                                    continue;
                                }
                                if ((eventName == "opened" || eventName == "closed")
                                    && item.value("children").toArray().isEmpty()) {
                                    continue;
                                }
                                sendDbusMenuEvent(currentMenuService, currentMenuPath, itemId, eventName);
                            }
                        });
                    }

                    QTimer poll;
                    QObject::connect(&poll, &QTimer::timeout, &app, [&]() {
                        if (wl_display_roundtrip(display) < 0) {
                            fail("watch-roundtrip-failed", display);
                            app.exit(2);
                            return;
                        }
                        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
                        const QByteArray currentJson = QJsonDocument(currentSnapshot()).toJson(QJsonDocument::Compact);
                        if (currentJson != lastJson) {
                            std::cout << currentJson.constData() << '\n' << std::flush;
                            lastJson = currentJson;
                        }
                    });
                    poll.start(1000);
                    result = app.exec();
                } else {
                    const QString activeMenu = initial.value("activeWindowMenuExported").toBool()
                        ? "true"
                        : (initial.value("activeWindowId").toString().isEmpty() ? "unknown" : "false");
                    std::cout
                        << "status=ok"
                        << " protocol=org_kde_plasma_window_management"
                        << " advertised_version=" << global.version
                        << " window_count=" << management->windows().size()
                        << " active_window_present=" << (management->activeWindow() ? "true" : "false")
                        << " active_window_menu_exported=" << activeMenu.toStdString()
                        << " appmenu_protocol_available=" << (appMenuProtocolAvailable ? "true" : "false")
                        << " workspace_read=" << (initial.value("workspaces").toObject().value("available").toBool() ? "true" : "false");
                    if (menuCheckMode) {
                        int rootItemCount = -1;
                        const QString layoutStatus = dbusMenuLayoutStatus(management->activeWindow(), &rootItemCount);
                        std::cout << " dbusmenu_layout=" << layoutStatus.toStdString();
                        if (rootItemCount >= 0) {
                            std::cout << " dbusmenu_root_items=" << rootItemCount;
                        }
                    }
                    std::cout << '\n';
                    // Let KWayland finish queued icon deserialization before the GUI app is torn down.
                    QEventLoop settle;
                    QTimer::singleShot(500, &settle, &QEventLoop::quit);
                    settle.exec();
                }
            }
        }
    }

    registry.reset();
    wl_display_disconnect(display);
    return result;
}
