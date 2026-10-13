#!/bin/sh
#
# Final command for the rings widget: writes the canvas widget payloads and a
# shots.json manifest into ARC_FINAL_OUT, then exits 3 because the SwiftUI
# widget can't be built or rendered on Windows.
#
# Exit: 1 a payload assertion failed, 3 payloads verified but not rendered.

set -eu

ARC_FINAL_OUT="${ARC_FINAL_OUT:-build/scenario}"
export ARC_FINAL_OUT

flutter test --tags scenario test/scenario/widget_payload_scenario_test.dart || exit 1

render_skip='SwiftUI widget cannot be built or rendered on Windows (no Xcode); owner: repo owner, on a Mac before the next sideload (docs/2026-06-14-mac-handoff-widget-proxy.md)'

cat > "$ARC_FINAL_OUT/shots.json" <<EOF
[
  {
    "name": "Widget board",
    "files": ["widget-watch.json", "widget-care.json", "widget-ahead.json"],
    "steps": [
      { "step": "widget payload: watch", "state": "pass" },
      { "step": "widget payload: care", "state": "pass" },
      { "step": "widget payload: ahead", "state": "pass" },
      { "step": "widget render: watch", "state": "skip", "detail": "$render_skip" },
      { "step": "widget render: care", "state": "skip", "detail": "$render_skip" },
      { "step": "widget render: ahead", "state": "skip", "detail": "$render_skip" },
      { "step": "widget render: empty", "state": "skip", "detail": "$render_skip" }
    ]
  }
]
EOF

echo 'could not verify: the SwiftUI widget was not built or rendered (no Xcode on Windows); payloads verified'
exit 3
