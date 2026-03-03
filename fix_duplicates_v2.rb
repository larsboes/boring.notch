require 'xcodeproj'

project_path = 'boringNotch.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'boringNotch'
target = project.targets.find { |t| t.name == target_name }

# 1. Remove ALL existing file references for these names
file_names = ['PluginManager+ViewHelpers.swift', 'PluginMusicControlsView.swift']

project.files.each do |file_ref|
  if file_names.include?(file_ref.display_name)
    puts "Removing file reference: #{file_ref.display_name} (path: #{file_ref.path})"
    
    # Remove from all build phases
    target.build_phases.each do |phase|
      phase.files.each do |build_file|
        if build_file.file_ref == file_ref
          phase.remove_build_file(build_file)
        end
      end
    end
    
    # Remove from its group
    if file_ref.parent.is_a?(Xcodeproj::Project::Object::PBXGroup)
      file_ref.parent.children.delete(file_ref)
    end
    
    # Remove from project
    file_ref.remove_from_project
  end
end

# 2. Add the correct ones
files_to_add = [
  'boringNotch/Plugins/Core/PluginManager+ViewHelpers.swift',
  'boringNotch/Plugins/BuiltIn/MusicPlugin/Views/PluginMusicControlsView.swift'
]

def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == name }
  existing || parent.new_group(name)
end

files_to_add.each do |file_path|
  puts "Adding #{file_path}..."
  
  # Navigate/create group hierarchy
  group = project.main_group
  parts = File.dirname(file_path).split('/')
  parts.each do |name|
    group = find_or_create_group(group, name)
  end
  
  # Add the file
  file_ref = group.new_file(File.absolute_path(file_path))
  target.add_file_references([file_ref])
  puts "✅ Added #{file_path} to target"
end

project.save
puts "Project saved."
