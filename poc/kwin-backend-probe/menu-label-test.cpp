#include "menu-label.h"

#include <array>
#include <iostream>

int main()
{
    struct TestCase {
        QString input;
        QString expected;
    };

    const std::array cases{
        TestCase{QStringLiteral("_File"), QStringLiteral("File")},
        TestCase{QStringLiteral("Save _As"), QStringLiteral("Save As")},
        TestCase{QStringLiteral("__literal"), QStringLiteral("_literal")},
        TestCase{QStringLiteral("A__B"), QStringLiteral("A_B")},
        TestCase{QStringLiteral("trailing_"), QStringLiteral("trailing_")},
    };

    for (std::size_t i = 0; i < cases.size(); ++i) {
        if (displayDbusMenuLabel(cases[i].input) != cases[i].expected) {
            std::cerr << "dbusmenu-label-test=failed case=" << i << '\n';
            return 1;
        }
    }

    std::cout << "dbusmenu-label-test=passed cases=" << cases.size() << '\n';
    return 0;
}
