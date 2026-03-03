1. **Explore History Screen**
   - Read `zubia/lib/screens/history_screen.dart` to identify missing tooltips and missing interactions on placeholder UI elements.
2. **Apply UX improvements**
   - Add `tooltip: 'Search history'` to the search `IconButton`.
   - Make the dummy "Play" container in `_HistoryCard` interactive by wrapping it in `Semantics`, `Tooltip`, and `GestureDetector`.
   - Provide a "Coming soon" snackbar and haptic feedback when the "Play" button is tapped, ensuring the interface doesn't feel broken.
3. **Verify the code**
   - Run `dart format .` and `flutter analyze` inside the `zubia` directory.
   - Run existing tests `flutter test`.
4. **Pre-commit checks**
   - Complete pre-commit steps to ensure proper testing, verifications, reviews and reflections are done.
5. **Submit**
   - Create a commit describing the UX improvements and submit.
