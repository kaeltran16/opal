import 'package:flutter/material.dart';

import '../theme/theme.dart';

const String saveFailedCopy = "Couldn't save. Try again.";
const String deleteFailedCopy = "Couldn't delete. Try again.";

const double _padHorizontal = 16;
const double _padVertical = 12;

/// A calm inline note that a write failed, announced as it appears.
class FailureNote extends StatelessWidget {
  const FailureNote([this.text = saveFailedCopy, Key? key]) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: _padHorizontal, vertical: _padVertical),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(Radii.inset),
        ),
        child: Text(text, style: AppType.subhead.copyWith(color: c.ink)),
      ),
    );
  }
}
