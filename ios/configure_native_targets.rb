#!/usr/bin/env ruby
# U25/U26 — wire the staged native code into the Xcode project:
#   * add the four Runner-target Swift files to Runner's compile sources
#   * create the OpalWidgets widget-extension target (Live Activity) + embed it
#
# NOTE: the HealthKit entitlement (U27) is deliberately NOT added — it cannot be
# provisioned by a free Apple Personal Team, so adding it breaks device signing.
# HealthKitService degrades gracefully without it; revisit when a paid Apple
# Developer account is available.
#
# Driven with the `xcodeproj` gem (the library CocoaPods itself uses) rather than
# hand-editing the pbxproj. Idempotent: re-running skips work already done.

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Runner.xcodeproj')
RUNNER_BUNDLE_ID = 'com.opal.opal'
WIDGET_NAME = 'OpalWidgets'
WIDGET_BUNDLE_ID = "#{RUNNER_BUNDLE_ID}.#{WIDGET_NAME}"
DEPLOYMENT_TARGET = '26.0'
SWIFT_VERSION = '5.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

# Runner entitlements (no App Group — a free team can't provision one; the
# rings widget syncs over HTTP via the proxy instead).
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# --- helper: get-or-create a group whose `path` is relative to its parent --
# (so file refs underneath can be plain basenames and resolve correctly).
def group_at(parent, name, path = name)
  parent[name] || parent.new_group(name, path)
end

# --- helper: add a file (by basename, relative to `group`'s path) to a group
#     and to each target's compile sources.
def add_source(project, group, basename, *targets)
  ref = group.files.find { |f| f.path == basename } || group.new_reference(basename)
  targets.each do |t|
    unless t.source_build_phase.files_references.include?(ref)
      t.source_build_phase.add_file_reference(ref)
    end
  end
  ref
end

# ---------------------------------------------------------------------------
# B1 — add the four Runner-target Swift files to Runner's compile sources.
#      OpalWorkoutAttributes is shared, so it is also added to OpalWidgets below.
# ---------------------------------------------------------------------------
# The existing 'Runner' group already has path 'Runner', so subgroups carry a
# path relative to it ('LiveActivities', 'Intents') and files are basenames.
runner_group = group_at(project.main_group, 'Runner')
la_group = group_at(runner_group, 'LiveActivities')
intents_group = group_at(runner_group, 'Intents')

attributes_ref = add_source(project, la_group, 'OpalWorkoutAttributes.swift', runner)
add_source(project, la_group, 'OpalLiveActivityBridge.swift', runner)
add_source(project, intents_group, 'OpalAppIntents.swift', runner)
add_source(project, intents_group, 'OpalIntentsBridge.swift', runner)

# Rings-widget sync bridge (Runner side; the `opal/widget_sync` channel).
widgets_group = group_at(runner_group, 'Widgets')
add_source(project, widgets_group, 'OpalWidgetSyncBridge.swift', runner)

# ---------------------------------------------------------------------------
# B2 — create the OpalWidgets app-extension target (the Live Activity widget).
# ---------------------------------------------------------------------------
widget = project.targets.find { |t| t.name == WIDGET_NAME }
unless widget
  widget = project.new_target(
    :app_extension, WIDGET_NAME, :ios, DEPLOYMENT_TARGET, project.products_group, :swift
  )
end

# Top-level OpalWidgets group (path relative to project root = ios/).
widget_group = group_at(project.main_group, WIDGET_NAME)
add_source(project, widget_group, 'OpalWorkoutLiveActivity.swift', widget)
add_source(project, widget_group, 'OpalWidgetsBundle.swift', widget)
add_source(project, widget_group, 'OpalRingsWidget.swift', widget)
# Rings snapshot + its proxy fetch: widget-only (the Runner bridge just nudges a
# reload, so it no longer references RingsSnapshot).
add_source(project, widget_group, 'OpalRingsSnapshot.swift', widget)
# Shared attributes: member of BOTH targets.
widget.source_build_phase.add_file_reference(attributes_ref) unless
  widget.source_build_phase.files_references.include?(attributes_ref)
# Surface the extension Info.plist in the project tree.
unless widget_group.files.any? { |f| f.path == 'Info.plist' }
  widget_group.new_reference('Info.plist')
end

widget.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = WIDGET_BUNDLE_ID
  s['CODE_SIGN_ENTITLEMENTS'] = 'OpalWidgets/OpalWidgets.entitlements'
  s['INFOPLIST_FILE'] = 'OpalWidgets/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['SWIFT_VERSION'] = SWIFT_VERSION
  s['SKIP_INSTALL'] = 'YES'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['CLANG_ENABLE_MODULES'] = 'YES'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'
  ]
  # Match Runner's per-config optimization so debug stays fast.
  s['SWIFT_OPTIMIZATION_LEVEL'] = config.name == 'Debug' ? '-Onone' : '-O'
  s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] ||= (config.name == 'Debug' ? 'DEBUG' : '')
end

# ---------------------------------------------------------------------------
#      embed the extension into Runner (dependency + Embed App Extensions).
# ---------------------------------------------------------------------------
runner.add_dependency(widget) unless runner.dependencies.any? { |d| d.target == widget }

embed_phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins # PlugIns (13)
end
unless embed_phase.files_references.include?(widget.product_reference)
  bf = embed_phase.add_file_reference(widget.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Resolve the Xcode build cycle (ExtractAppIntentsMetadata <-> embed appex):
# the extension must be embedded BEFORE Flutter's "Thin Binary" script phase,
# otherwise the appex copy and the app's Info.plist processing form a loop.
phases = runner.build_phases
thin_idx = phases.index { |p| p.respond_to?(:display_name) && p.display_name == 'Thin Binary' }
if thin_idx
  phases.delete(embed_phase)
  thin_idx = phases.index { |p| p.respond_to?(:display_name) && p.display_name == 'Thin Binary' }
  phases.insert(thin_idx, embed_phase)
end

# Register the new widget target in the project attributes (signing UI defaults).
attrs = project.root_object.attributes
attrs['TargetAttributes'] ||= {}
attrs['TargetAttributes'][widget.uuid] ||= {}
attrs['TargetAttributes'][widget.uuid]['CreatedOnToolsVersion'] = '26.5'

project.save

puts 'OK — saved Runner.xcodeproj'
puts "Targets now: #{project.targets.map(&:name).join(', ')}"
puts "Runner sources: #{runner.source_build_phase.files_references.map(&:display_name).sort.join(', ')}"
puts "Widget sources: #{widget.source_build_phase.files_references.map(&:display_name).sort.join(', ')}"
puts "Runner copy phases: #{runner.copy_files_build_phases.map(&:name).join(', ')}"
