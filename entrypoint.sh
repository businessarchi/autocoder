#!/bin/bash
set -e

# Copy Claude credentials from mounted read-only volume to writable location
# The mount is read-only so we copy the auth files and ensure write permissions
if [ -d "/claude-credentials" ]; then
    echo "Copying Claude credentials..."
    # Copy only the essential auth files, not the whole directory
    cp -f /claude-credentials/credentials.json /home/autocoder/.claude/ 2>/dev/null || true
    cp -f /claude-credentials/config.json /home/autocoder/.claude/ 2>/dev/null || true
    cp -f /claude-credentials/settings.json /home/autocoder/.claude/ 2>/dev/null || true
    # Ensure the user owns everything and can write
    chmod -R 755 /home/autocoder/.claude
fi

# Configure git for commits
git config --global user.email "${GIT_EMAIL:-autocoder@business-architecte.fr}"
git config --global user.name "${GIT_USER:-Autocoder}"

# Store credentials for push (if GIT_TOKEN is set)
if [ -n "$GIT_TOKEN" ]; then
    git config --global credential.helper store
    echo "https://${GIT_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials
fi

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
