## 2024-05-23 - Accessibility of Custom Toggles
**Learning:** Custom toggle buttons implemented with `GestureDetector` lack accessibility traits. Wrapping them in `Semantics(button: true, selected: boolean, label: string)` makes them accessible to screen readers, conveying state changes properly.
**Action:** Always wrap custom interactive widgets in `Semantics` to expose their role and state.

## 2024-05-24 - Feedback for Placeholder UI
**Learning:** Buttons that do nothing (placeholder for future features) confuse users and feel "broken". Providing a simple `SnackBar` ("Coming soon") transforms a "broken" interaction into a helpful status update.
**Action:** Never leave `onTap` empty for visible interactive elements.
