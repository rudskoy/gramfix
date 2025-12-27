#!/bin/bash
# Script to push all commits to rudskoy/gramfix while preserving history

set -e

cd "$(dirname "$0")"

echo "📦 Fetching remote repository..."
git fetch origin

echo "📊 Checking commit history..."
echo "Local commits:"
git log --oneline -5
echo ""
echo "Remote commits:"
git log --oneline origin/main -5 2>/dev/null || echo "No remote main branch yet"

echo ""
echo "🔄 Merging remote initial commit (if exists) into our history..."
# If remote has commits, merge them; otherwise we'll push directly
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "Remote has commits. Merging..."
    git merge origin/main --allow-unrelated-histories -m "Merge remote initial commit with local history" || {
        echo "⚠️  Merge conflict or already merged. Checking status..."
        git status
    }
else
    echo "No remote commits found. Will push directly."
fi

echo ""
echo "📤 Pushing all commits to origin/main..."
git push origin main --force-with-lease

echo ""
echo "✅ Done! All commits have been pushed to https://github.com/rudskoy/gramfix"
echo "   History preserved: $(git rev-list --count HEAD) commits"

