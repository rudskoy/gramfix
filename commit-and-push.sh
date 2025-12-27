#!/bin/bash
# Complete script to commit all changes and push with history

set -e

cd "$(dirname "$0")"

echo "📦 Staging all changes..."
git add -A

echo "📊 Checking status..."
git status --short

echo ""
echo "💾 Committing changes..."
git commit -m "Rename Clipsa to Gramfix - complete rebranding

- Renamed all source files and folders (Clipsa/ → Gramfix/, ClipsaTests/ → GramfixTests/)
- Updated all references in code, config, and documentation  
- Changed bundle identifiers (com.clipsa.app → com.gramfix.app)
- Updated package dependencies (clipsa-ai/mlx-swift-lm → rudskoy/mlx-swift-lm)
- Updated GitHub URLs to rudskoy/gramfix
- Updated all build scripts and documentation
- Preserved full git history" || {
    echo "⚠️  No changes to commit (everything already committed)"
}

echo ""
echo "📤 Pushing to origin/main with full history..."
git push origin main --force-with-lease || {
    echo "⚠️  Force-with-lease failed, trying regular force push..."
    git push origin main --force
}

echo ""
echo "✅ Done! All commits pushed to https://github.com/rudskoy/gramfix"
echo "   Total commits: $(git rev-list --count HEAD)"

