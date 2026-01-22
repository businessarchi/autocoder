#!/bin/bash
set -e

# Clone external projects from environment variables
# Format: CLONE_PROJECT_<name>=<git_url>
# Example: CLONE_PROJECT_BAERP=https://github.com/user/ba-erp.git

for var in $(env | grep '^CLONE_PROJECT_' | cut -d= -f1); do
    project_name=$(echo "$var" | sed 's/CLONE_PROJECT_//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    git_url="${!var}"
    project_dir="/app/projects/$project_name"

    if [ -n "$git_url" ]; then
        if [ -d "$project_dir/.git" ]; then
            echo "Updating $project_name from $git_url..."
            cd "$project_dir" && git pull || echo "Warning: git pull failed for $project_name"
        else
            echo "Cloning $project_name from $git_url..."
            rm -rf "$project_dir"
            git clone "$git_url" "$project_dir"
        fi
    fi
done

# Start the server
exec python -m uvicorn server.main:app --host 0.0.0.0 --port 8888
