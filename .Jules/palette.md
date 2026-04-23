## 2024-05-23 - Accessibility of Custom Toggles
**Learning:** Custom toggle buttons implemented with `GestureDetector` lack accessibility traits. Wrapping them in `Semantics(button: true, selected: boolean, label: string)` makes them accessible to screen readers, conveying state changes properly.
**Action:** Always wrap custom interactive widgets in `Semantics` to expose their role and state.

## 2024-05-24 - Feedback for Placeholder UI
**Learning:** Buttons that do nothing (placeholder for future features) confuse users and feel "broken". Providing a simple `SnackBar` ("Coming soon") transforms a "broken" interaction into a helpful status update.
**Action:** Never leave `onTap` empty for visible interactive elements.

## 2024-05-25 - Conditional Tooltips for Disabled States
**Learning:** When attempting to disable a `Tooltip` (e.g., when a button becomes enabled and no longer needs an explanation), passing an empty string (`''`) to the `message` property does not disable the tooltip. Instead, Flutter renders a small, empty black box when the user hovers over the element.
**Action:** Always conditionally wrap the widget in the `Tooltip` only when the disabled state needs explaining, rather than attempting to pass an empty string to an always-present `Tooltip` widget.

## 2024-05-26 - Helpful Empty States with Actions
**Learning:** Empty states with static text (like "No users found") leave the user guessing what went wrong, and require manual actions to fix the problem. By reflecting the search input back into the empty state ("No users match [search_query]") and adding a clear search action, the error is immediately clear, and recovery is actionable.
**Action:** Always provide the user's input context inside of search empty states, and add an action like "Clear Search" or "Reset Filters" so the user can easily proceed.

## 2024-05-27 - Smoothing Binary UI Transitions
**Learning:** Binary state changes (like switching an icon or replacing an empty state with a list) feel jarring when they snap instantly. Using `AnimatedSwitcher` to cross-fade these components significantly increases the perceived polish and quality of the interaction. However, this often breaks synchronous widget tests because `AnimatedSwitcher` temporarily holds multiple widgets in the tree during the transition.
**Action:** Use `AnimatedSwitcher` for state-driven UI swaps, ensure `ValueKey`s are present to trigger the transition, and update associated widget tests to use `pumpAndSettle()` and semantic-based finders (rather than simple `find.byIcon()`) to account for the animation duration.

## 2024-05-28 - Search Input Keyboard Optimization
**Learning:** Generic text inputs on mobile devices often trigger autocorrect and suggest completely irrelevant terms when the user is searching for specific identifiers like usernames. This causes frustration when the OS "fixes" a username search. Furthermore, the generic "Return" or "Done" keyboard action doesn't communicate the intent of the input.
**Action:** Always set `autocorrect: false`, `enableSuggestions: false`, and `textInputAction: TextInputAction.search` for precise identifier searches (like usernames) in Flutter to disable OS interference and provide the correct visual cue on the software keyboard.

## 2024-04-23 - Add Actionable Recovery Paths for Transient Errors
**Learning:** For transient network errors, static `SnackBar` messages create friction by forcing the user to manually re-navigate and re-initiate the action.
**Action:** Include actionable `SnackBarAction` buttons (e.g., 'RETRY') that immediately re-invoke the failed operation, providing a seamless context-aware recovery path.
