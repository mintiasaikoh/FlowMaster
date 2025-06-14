#!/usr/bin/env python3
import plistlib
import sys
import os

def analyze_project(project_path):
    """Analyze Xcode project for duplicate file references"""
    pbxproj_path = os.path.join(project_path, "project.pbxproj")
    
    print("Analyzing project file:", pbxproj_path)
    print("")
    
    # Note: Modern Xcode projects use a different format
    # For synchronized file groups, duplicates are typically in the file system
    
    # Check for duplicate Swift files
    swift_files = {}
    for root, dirs, files in os.walk(os.path.dirname(project_path)):
        for file in files:
            if file.endswith('.swift'):
                if file not in swift_files:
                    swift_files[file] = []
                swift_files[file].append(os.path.join(root, file))
    
    print("Duplicate Swift files found:")
    has_duplicates = False
    for filename, paths in swift_files.items():
        if len(paths) > 1:
            has_duplicates = True
            print(f"\n{filename}:")
            for path in paths:
                print(f"  - {path}")
    
    if not has_duplicates:
        print("No duplicate Swift files found.")
    
    return has_duplicates

if __name__ == "__main__":
    project_path = sys.argv[1] if len(sys.argv) > 1 else "FlowMaster.xcodeproj"
    analyze_project(project_path)
