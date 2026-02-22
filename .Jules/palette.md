## 2024-05-23 - Accessibility of Custom Toggles
**Learning:** Custom toggle buttons implemented with `GestureDetector` lack accessibility traits. Wrapping them in `Semantics(button: true, selected: boolean, label: string)` makes them accessible to screen readers, conveying state changes properly.
**Action:** Always wrap custom interactive widgets in `Semantics` to expose their role and state.
