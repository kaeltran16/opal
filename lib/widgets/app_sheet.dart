import 'package:flutter/material.dart';

import '../theme/theme.dart';

const double _grabberWidth = 36;
const double _grabberHeight = 5;
const double _bottomInset = 34;

const Key appSheetGrabberKey = ValueKey('app_sheet.grabber');

/// The app's bottom sheet: a flat `surface` panel with a grabber over a
/// `scrim`. [scrollable] lets tall content (a list) take the screen height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = false,
}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    // above the shell's floating bars, which would cover the sheet's bottom.
    useRootNavigator: true,
    isScrollControlled: scrollable,
    useSafeArea: scrollable,
    backgroundColor: c.surface,
    barrierColor: c.scrim,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
    ),
    builder: (context) => _AppSheet(child: builder(context)),
  );
}

class _AppSheet extends StatelessWidget {
  const _AppSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // the keyboard inset keeps a search field in the sheet above the keyboard.
    final bottom =
        _bottomInset + MediaQuery.viewPaddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Spacing.lg,
        children: [
          Center(
            child: Container(
              key: appSheetGrabberKey,
              width: _grabberWidth,
              height: _grabberHeight,
              decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(Radii.pill)),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}
