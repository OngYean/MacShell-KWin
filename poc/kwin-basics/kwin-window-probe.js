// One-shot, read-only KWin 6.8.x scripting probe.
// It deliberately reports no window titles, identifiers, or geometry.
console.info(
    "[macshell-kwin-readonly-probe] windowCount=" + workspace.windowList().length +
    " activeWindowPresent=" + Boolean(workspace.activeWindow)
);
