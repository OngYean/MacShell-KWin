#pragma once

#include <QString>

inline QString displayDbusMenuLabel(const QString &label)
{
    QString displayLabel;
    displayLabel.reserve(label.size());

    for (qsizetype i = 0; i < label.size(); ++i) {
        if (label.at(i) != QLatin1Char('_')) {
            displayLabel.append(label.at(i));
            continue;
        }

        if (i + 1 < label.size() && label.at(i + 1) == QLatin1Char('_')) {
            displayLabel.append(QLatin1Char('_'));
            ++i;
        } else if (i + 1 == label.size()) {
            displayLabel.append(QLatin1Char('_'));
        }
    }

    return displayLabel;
}
