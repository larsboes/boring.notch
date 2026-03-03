#!/usr/bin/env ruby
# manage_xcode_files.rb
# Usage:
#   ruby manage_xcode_files.rb add <file_path> [group_path]
#   ruby manage_xcode_files.rb remove <file_path>
#
# Example:
#   ruby manage_xcode_files.rb add boringNotch/Plugins/Services/NewService.swift
#   ruby manage_xcode_files.rb remove boringNotch/models/OldModel.swift

require 'xcodeproj'

PROJECT_PATH = 'boringNotch.xcodeproj'
TARGET_NAME = 'boringNotch'

def main
  command = ARGV[0]
  
  if command.nil?
    puts "Usage: ruby manage_xcode_files.rb <add|remove> <file_path>"
    exit 1
  end

  project = Xcodeproj::Project.open(PROJECT_PATH)
  target = project.targets.find { |t| t.name == TARGET_NAME }

  unless target
    puts "❌ Error: Target '#{TARGET_NAME}' not found."
    exit 1
  end

  case command
  when 'add'
    file_paths = ARGV[1..-1]
    if file_paths.empty?
      puts "❌ Error: No file paths provided for add."
      exit 1
    end
    file_paths.each do |path|
      add_file(project, target, path)
    end
  when 'remove'
    file_paths = ARGV[1..-1]
    if file_paths.empty?
      puts "❌ Error: No file paths provided for remove."
      exit 1
    end
    file_paths.each do |path|
      remove_file(project, target, path)
    end
  else
    puts "❌ Error: Unknown command '#{command}'"
    exit 1
  end

  project.save
  puts "\n✅ Project saved successfully!"
end

def find_or_create_group(parent, name)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == name }
  existing || parent.new_group(name)
end

def add_file(project, target, file_path)
  # Infer group from file path directory structure
  # Assuming file_path is relative to project root
  dir_path = File.dirname(file_path)
  group_path = dir_path.split('/')
  
  # Navigate/create group hierarchy
  group = project.main_group
  group_path.each do |name|
    group = find_or_create_group(group, name)
  end

  file_name = File.basename(file_path)
  existing_file = group.files.find { |f| f.path && f.path.end_with?(file_name) }

  if existing_file
    puts "⏭  #{file_name} already in group"
    unless target.source_build_phase.files_references.include?(existing_file)
      target.add_file_references([existing_file])
      puts "   ↳ Added to target '#{TARGET_NAME}'"
    end
  else
    file_ref = group.new_file(file_path)
    target.add_file_references([file_ref])
    puts "✅ Added #{file_name} to #{group_path.join('/')}"
  end
end

def remove_file(project, target, file_path)
  file_name = File.basename(file_path)
  
  # Search for the file reference in the project
  # We search recursively
  file_ref = project.files.find { |f| f.path && f.path.end_with?(file_name) }
  
  unless file_ref
    puts "⚠️  File reference not found for: #{file_name}"
    return
  end
  
  # Remove from target
  target.source_build_phase.remove_file_reference(file_ref)
  
  # Remove from group
  if file_ref.parent.is_a?(Xcodeproj::Project::Object::PBXGroup)
    file_ref.parent.children.delete(file_ref)
  end
  
  # Remove the file reference object itself
  file_ref.remove_from_project
  
  puts "🗑️  Removed #{file_name} from project"
end

main
