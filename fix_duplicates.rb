require 'xcodeproj'

project_path = 'boringNotch.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target_name = 'boringNotch'
target = project.targets.find { |t| t.name == target_name }

files_to_remove = [
  'boringNotch/Core/PluginManager+ViewHelpers.swift',
  'boringNotch/Core/PluginMusicControlsView.swift'
]

files_to_remove.each do |file_path|
  puts "Processing #{file_path}..."
  
  # Find the file reference with this exact path
  file_ref = project.files.find { |f| f.real_path.to_s.end_with?(file_path) }
  
  if file_ref
    puts "Found file reference: #{file_ref.path}"
    
    # Remove from all build phases in the target
    target.build_phases.each do |phase|
      phase.files.each do |build_file|
        if build_file.file_ref == file_ref
          puts "Removing from build phase: #{phase.isa}"
          phase.remove_build_file(build_file)
        end
      end
    end
    
    # Remove from its group
    if file_ref.parent.is_a?(Xcodeproj::Project::Object::PBXGroup)
      puts "Removing from group: #{file_ref.parent.display_name}"
      file_ref.parent.children.delete(file_ref)
    end
    
    # Remove from project
    file_ref.remove_from_project
    puts "✅ Removed #{file_path}"
  else
    puts "⚠️  Could not find file reference for #{file_path}"
  end
end

project.save
puts "Project saved."
