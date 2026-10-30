#!/usr/bin/env ruby
# U25/U26 — wire the staged native code into the Xcode project:
#   * add the four Runner-target Swift files to Runner's compile sources
#   * create the OpalWidgets widget-extension target (Live Activity) + embed it
#   * create the OpalWatch watchOS app target + embed it (Runner.app/Watch)
#
# The HealthKit entitlement lives in Runner/Runner.entitlements; the TestFlight
# workflow's automatic signing turns the capability on for the App ID.
#
# Driven with the `xcodeproj` gem (the library CocoaPods itself uses) rather than
# hand-editing the pbxproj. Idempotent: re-running skips work already done.

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'Runner.xcodeproj')
RUNNER_BUNDLE_ID = 'com.kael.opal'
WIDGET_NAME = 'OpalWidgets'
WIDGET_BUNDLE_ID = "#{RUNNER_BUNDLE_ID}.#{WIDGET_NAME}"
# the target name must match its folder: flutter build ios finds the watch app
# through ios/<target>/Info.plist and only then stops forcing -sdk iphoneos
WATCH_NAME = 'OpalWatch'
WATCH_BUNDLE_ID = "#{RUNNER_BUNDLE_ID}.watchkitapp"
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

# Apple Health bridge (Runner side; the `opal/health` channel).
health_group = group_at(runner_group, 'Health')
add_source(project, health_group, 'OpalHealthBridge.swift', runner)

# Phone end of the Watch link. The message keys are shared with OpalWatch below.
# The relay hands Watch logs to Dart, starting a headless engine when needed.
watch_link_group = group_at(runner_group, 'Watch')
message_ref = add_source(project, watch_link_group, 'OpalWatchMessage.swift', runner)
add_source(project, watch_link_group, 'OpalWatchSession.swift', runner)
add_source(project, watch_link_group, 'OpalWatchRelay.swift', runner)

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
# B2b — give the widget target a base xcconfig so its Info.plist
#       $(PAL_BASE_URL)/$(PAL_PROVISIONING_KEY) resolve to the backend.
# Unlike Runner, this target has no base config, so without this the proxy
# vars are undefined and the widget's plist substitutes empty strings (the
# widget then can't fetch its snapshot). PalConfig.generated.xcconfig is
# gitignored and written by scripts/build_ipa.sh from the same config the
# app's dart-defines use; it's absent for standalone builds, where the vars
# simply resolve empty and the widget falls back to no backend.
# ---------------------------------------------------------------------------
flutter_group = project.main_group.find_subpath('Flutter')
pal_xcconfig = 'Flutter/PalConfig.generated.xcconfig'
pal_ref = flutter_group.files.find { |f| f.path == pal_xcconfig } ||
          flutter_group.new_reference(pal_xcconfig)
pal_ref.last_known_file_type = 'text.xcconfig'
widget.build_configurations.each do |config|
  config.base_configuration_reference = pal_ref
end
# Stub the file if absent so the base-config reference never dangles on a fresh
# checkout / direct Xcode build (build_ipa.sh overwrites it with real values).
pal_path = File.join(__dir__, pal_xcconfig)
unless File.exist?(pal_path)
  File.write(pal_path, "// AUTO-GENERATED stub — overwritten by scripts/build_ipa.sh; do not commit.\n" \
                       "PAL_BASE_URL =\nPAL_PROVISIONING_KEY =\n")
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

# ---------------------------------------------------------------------------
# B3 — create the OpalWatch watchOS app (SwiftUI, companion of Runner).
# ---------------------------------------------------------------------------
watch = project.targets.find { |t| t.name == WATCH_NAME }
unless watch
  watch = project.new_target(
    :application, WATCH_NAME, :watchos, DEPLOYMENT_TARGET, project.products_group, :swift
  )
end

watch_group = group_at(project.main_group, WATCH_NAME)
add_source(project, watch_group, 'OpalWatchApp.swift', watch)
add_source(project, watch_group, 'OpalWatchLink.swift', watch)
add_source(project, watch_group, 'OpalWatchViews.swift', watch)
# Shared message keys: member of BOTH targets.
watch.source_build_phase.add_file_reference(message_ref) unless
  watch.source_build_phase.files_references.include?(message_ref)
unless watch_group.files.any? { |f| f.path == 'Info.plist' }
  watch_group.new_reference('Info.plist')
end
assets_ref = watch_group.files.find { |f| f.path == 'Assets.xcassets' } ||
             watch_group.new_reference('Assets.xcassets')
watch.resources_build_phase.add_file_reference(assets_ref) unless
  watch.resources_build_phase.files_references.include?(assets_ref)

# Info.plist takes its version from FLUTTER_BUILD_NAME/NUMBER like Runner's
# (Xcode rejects a watch app whose version differs from its companion's), so
# the target reads them from Generated.xcconfig.
generated_ref = flutter_group.files.find { |f| f.path == 'Flutter/Generated.xcconfig' }
raise 'Flutter/Generated.xcconfig reference not found' unless generated_ref
watch.build_configurations.each do |config|
  config.base_configuration_reference = generated_ref
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = WATCH_BUNDLE_ID
  s['INFOPLIST_FILE'] = 'OpalWatch/Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  # the project-level settings are iOS-only; override them for the watch
  s['SDKROOT'] = 'watchos'
  s['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['WATCHOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['SWIFT_VERSION'] = SWIFT_VERSION
  # embedded in Runner.app, so archive must not also install it at top level
  s['SKIP_INSTALL'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  s['SWIFT_OPTIMIZATION_LEVEL'] = config.name == 'Debug' ? '-Onone' : '-O'
  s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] ||= (config.name == 'Debug' ? 'DEBUG' : '')
end

# Embed the watch app into Runner (dependency + Embed Watch Content).
runner.add_dependency(watch) unless runner.dependencies.any? { |d| d.target == watch }

watch_embed_phase = runner.copy_files_build_phases.find { |p| p.name == 'Embed Watch Content' }
unless watch_embed_phase
  watch_embed_phase = runner.new_copy_files_build_phase('Embed Watch Content')
  watch_embed_phase.symbol_dst_subfolder_spec = :products_directory # 16
  watch_embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
end
unless watch_embed_phase.files_references.include?(watch.product_reference)
  bf = watch_embed_phase.add_file_reference(watch.product_reference)
  bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

# Resolve the Xcode build cycle (ExtractAppIntentsMetadata <-> embed appex):
# the extension must be embedded BEFORE Flutter's "Thin Binary" script phase,
# otherwise the appex copy and the app's Info.plist processing form a loop.
# The watch app is embedded the same way, so it goes there too.
phases = runner.build_phases
[embed_phase, watch_embed_phase].each do |phase|
  next unless phases.any? { |p| p.respond_to?(:display_name) && p.display_name == 'Thin Binary' }
  phases.delete(phase)
  thin_idx = phases.index { |p| p.respond_to?(:display_name) && p.display_name == 'Thin Binary' }
  phases.insert(thin_idx, phase)
end

# Register the new targets in the project attributes (signing UI defaults).
attrs = project.root_object.attributes
attrs['TargetAttributes'] ||= {}
[widget, watch].each do |t|
  attrs['TargetAttributes'][t.uuid] ||= {}
  attrs['TargetAttributes'][t.uuid]['CreatedOnToolsVersion'] = '26.5'
end

project.save

puts 'OK — saved Runner.xcodeproj'
puts "Targets now: #{project.targets.map(&:name).join(', ')}"
puts "Runner sources: #{runner.source_build_phase.files_references.map(&:display_name).sort.join(', ')}"
puts "Widget sources: #{widget.source_build_phase.files_references.map(&:display_name).sort.join(', ')}"
puts "Watch sources: #{watch.source_build_phase.files_references.map(&:display_name).sort.join(', ')}"
puts "Runner copy phases: #{runner.copy_files_build_phases.map(&:name).join(', ')}"
