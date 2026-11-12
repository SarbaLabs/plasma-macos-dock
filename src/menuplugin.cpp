// SPDX-License-Identifier: GPL-2.0-or-later
#include "menuplugin.h"
#include "applicationmenubackend.h"
#include <QtQml>

void MenuPlugin::registerTypes(const char *uri)
{
    qmlRegisterType<ApplicationMenuBackend>(uri, 1, 0, "ApplicationMenuBackend");
}
