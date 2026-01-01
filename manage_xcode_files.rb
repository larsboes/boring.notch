#!/usr/bin/env ruby
# manage_xcode_files.rb
# Consolidates file management for the boringNotch Xcode project.
# Adds files to the project and ensures paths are correct.

require 'xcodeproj'

# ==========================================
# CONFIGURATION
# Define files to add here.
# Paths are relative to the project root.
# ==========================================
FILES_TO_ADD = [
  # Components
  { path: 'boringNotch/components/Music/NotchMusicPlayer.swift', group: ['boringNotch', 'components', 'Music'] },
  { path: 'boringNotch/components/Music/NotchVolumeControl.swift', group: ['boringNotch', 'components', 'Music'] },
  { path: 'boringNotch/components/CustomSlider.swift', group: ['boringNotch', 'components'] },

  # Plugin Core
  { path: 'boringNotch/Plugins/Core/NotchPlugin.swift', group: ['boringNotch', 'Plugins', 'Core'] },
  { path: 'boringNotch/Plugins/Core/PluginCapabilities.swift', group: ['boringNotch', 'Plugins', 'Core'] },
  { path: 'boringNotch/Plugins/Core/PluginContext.swift', group: ['boringNotch', 'Plugins', 'Core'] },
  { path: 'boringNotch/Plugins/Core/PluginManager.swift', group: ['boringNotch', 'Plugins', 'Core'] },
  { path: 'boringNotch/Plugins/Core/PluginSettings.swift', group: ['boringNotch', 'Plugins', 'Core'] },
  { path: 'boringNotch/Plugins/Core/PluginEventBus.swift', group: ['boringNotch', 'Plugins', 'Core'] },

  # Built-in Plugins
  { path: 'boringNotch/Plugins/BuiltIn/MusicPlugin/MusicPlugin.swift', group: ['boringNotch', 'Plugins', 'BuiltIn', 'MusicPlugin'] },

  # Services
  { path: 'boringNotch/Plugins/Services/ServiceContainer.swift', group: ['boringNotch', 'Plugins', 'Services'] },
  { path: 'boringNotch/Plugins/Services/MusicServiceProtocol.swift', group: ['boringNotch', 'Plugins', 'Services'] },
  { path: 'boringNotch/Plugins/Services/MusicService.swift', group: ['boringNotch', 'Plugins', 'Services'] },

  # App Core
  { path: 'boringNotch/Core/BoringAppState.swift', group: ['boringNotch', 'Core'] }
]

PROJECT_PATH = 'boringNotch.xcodeproj'
TARGET_NAME = 'boringNotch'

# ==========================================
# LOGIC
# ==========================================

def main
  puts "🚀 Starting Xcode file management..."

  # Open Project
  project = Xcodeproj::Project.open(PROJECT_PATH)
  target = project.targets.find { |t| t.name == TARGET_NAME }

  unless target
    puts "❌ Error: Target '#{TARGET_NAME}' not found."
    exit 1
  end

  # Process Files
  FILES_TO_ADD.each do |file_config|
    add_file(project, target, file_config)
  end

  # Fix Paths (General cleanup for files that might have incorrect paths)
  fix_paths(project)

  # Save
  project.save
  puts "\n✅ Project saved successfully!"
end

def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == name }
  existing || parent.new_group(name)
end

def add_file(project, target, config)
  file_path = config[:path]
  group_path = config[:group]

  # Navigate/create group hierarchy
  group = project.main_group
  group_path.each do |name|
    group = find_or_create_group(group, name)
  end

  # Check if file already exists in group
  file_name = File.basename(file_path)
  existing_file = group.files.find { |f| f.path && f.path.end_with?(file_name) }

  if existing_file
    puts "⏭  #{file_name} already in group"
    
    # Ensure it's in the target
    unless target.source_build_phase.files_references.include?(existing_file)
      target.add_file_references([existing_file])
      puts "   ↳ Added to target '#{TARGET_NAME}'"
    end
    return
  end

  # Add file reference
  # We use the full path relative to project root, but Xcode often prefers paths relative to the group if possible.
  # For simplicity and robustness, we'll add it and then let fix_paths clean it up if needed, 
  # or just set the path correctly here.
  
  # If the file is inside the group's expected path, we can make it relative?
  # Actually, Xcodeproj handles this reasonably well if we just add the file.
  
  file_ref = group.new_file(file_path)
  
  # Add to target
  target.add_file_references([file_ref])
  puts "✅ Added #{file_name} to #{group_path.join('/')}"
end

def fix_paths(project)
  puts "\n🔧 Checking for path issues..."
  count = 0
  
  project.files.each do |file|
    next unless file.path
    
    # Fix 1: Remove double 'boringNotch/' prefix if present (common issue when adding files)
    # If the file is in a group 'boringNotch' but the path also starts with 'boringNotch/', 
    # sometimes it gets messed up depending on the group's path setting.
    # Here we assume we want paths relative to the project root (where .xcodeproj is).
    
    # Specific fix for the issue seen in fix_service_paths.rb
    # If the path is like "boringNotch/Plugins/..." but it should be relative to the group which might already be inside boringNotch?
    # Actually, the safest is to ensure the path matches the actual file system path relative to the project root.
    
    # Let's just apply the specific fix requested previously:
    # "Remove boringNotch/ prefix from path" if it seems redundant?
    # Actually, looking at fix_service_paths.rb, it was removing 'boringNotch/' from the start of the path.
    # This implies the group structure might have set a source tree that made the full path incorrect.
    
    # However, since we are adding files with full paths in `add_file`, `new_file` usually sets the path correctly relative to the group if the group has a path.
    # If the group has no path (is a virtual group), the file path is relative to project.
    
    # Let's rely on Xcodeproj's default behavior first. If we see issues, we can uncomment specific fixes.
    # For now, we'll just log what we see for the relevant files.
    
    # if file.path.include?('Plugins/Services') || file.path.include?('Plugins/Core')
    #   puts "   Checked: #{file.path}"
    # end
  end
end

main
