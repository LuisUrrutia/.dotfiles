#!/usr/bin/env fish

set -l functions_dir (status dirname)/../fish/functions
source "$functions_dir/skill_agent_dirs.fish"; or exit 1
source "$functions_dir/skill-link.fish"; or exit 1

set -l repository "$HOME/Projects/LuisUrrutia/skills"
set -l manifests "$repository"/*/SKILL.md
if test (count $manifests) -eq 0
    echo "No personal skills found in $repository; apply bootstrap repos first." >&2
    exit 1
end

skill-link (path dirname -- $manifests)
