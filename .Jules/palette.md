## 2024-05-23 - Accessibility of Custom Toggles
**Learning:** Custom toggle buttons implemented with `GestureDetector` lack accessibility traits. Wrapping them in `Semantics(button: true, selected: boolean, label: string)` makes them accessible to screen readers, conveying state changes properly.
**Action:** Always wrap custom interactive widgets in `Semantics` to expose their role and state.

## 2024-05-24 - Feedback for Placeholder UI
**Learning:** Buttons that do nothing (placeholder for future features) confuse users and feel "broken". Providing a simple `SnackBar` ("Coming soon") transforms a "broken" interaction into a helpful status update.
**Action:** Never leave `onTap` empty for visible interactive elements.

## 2024-05-25 - Conditional Tooltips for Disabled States
**Learning:** When attempting to disable a `Tooltip` (e.g., when a button becomes enabled and no longer needs an explanation), passing an empty string (`''`) to the `message` property does not disable the tooltip. Instead, Flutter renders a small, empty black box when the user hovers over the element.
**Action:** Always conditionally wrap the widget in the `Tooltip` only when the disabled state needs explaining, rather than attempting to pass an empty string to an always-present `Tooltip` widget.