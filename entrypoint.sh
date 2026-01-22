#!/bin/bash
set -e

# Clone external projects from environment variables
# Format: CLONE_PROJECT_<name>=<git_url>
# For private repos, use: https://<token>@github.com/user/repo.git
# Or set GIT_TOKEN and use: https://github.com/user/repo.git (token injected automatically)

for var in $(env | grep '^CLONE_PROJECT_' | cut -d= -f1); do
    project_name=$(echo "$var" | sed 's/CLONE_PROJECT_//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    git_url="${!var}"
    project_dir="/app/projects/$project_name"

    if [ -n "$git_url" ]; then
        # Inject GIT_TOKEN if set and URL doesn't already contain credentials
        if [ -n "$GIT_TOKEN" ] && [[ "$git_url" == https://github.com/* ]] && [[ "$git_url" != *@* ]]; then
            git_url="${git_url/https:\/\/github.com/https:\/\/${GIT_TOKEN}@github.com}"
        fi

        if [ -d "$project_dir/.git" ]; then
            echo "Updating $project_name..."
            cd "$project_dir" && git pull || echo "Warning: git pull failed for $project_name"
        else
            echo "Cloning $project_name..."
            rm -rf "$project_dir"
            git clone "$git_url" "$project_dir"
        fi
    fi
done

# Start the server
exec python -m uvicorn server.main:app --host 0.0.0.0 --port 8888
