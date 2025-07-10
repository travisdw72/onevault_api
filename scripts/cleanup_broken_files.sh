#!/bin/bash

echo "🧹 Cleaning up broken One Barn AI setup files..."
echo ""

# Files to delete (broken/outdated)
FILES_TO_DELETE=(
    "one_barn_ai_setup_plan.sql"
    "one_barn_corrected_setup.sql" 
    "one_barn_clean_setup.sql"
    "one_barn_phase2_corrected.sql"
    "one_barn_phase2_fixed.sql"
    "one_barn_phase2_final.sql"
    "check_roles.sql"
)

# Check if we're in the right directory
if [ ! -f "ONE_BARN_AI_COMPLETE_SETUP.sql" ]; then
    echo "❌ Error: Please run this script from the onevault_api directory"
    echo "   Expected to find ONE_BARN_AI_COMPLETE_SETUP.sql in current directory"
    exit 1
fi

echo "Files to delete:"
for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        echo "  ❌ $file (exists - will delete)"
    else
        echo "  ⚪ $file (not found - skip)"
    fi
done

echo ""
read -p "Continue with deletion? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Deleting files..."
    
    for file in "${FILES_TO_DELETE[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            echo "  ✅ Deleted: $file"
        fi
    done
    
    echo ""
    echo "🎉 Cleanup completed!"
    echo ""
    echo "Remaining files:"
    echo "  ✅ ONE_BARN_AI_COMPLETE_SETUP.sql (PRODUCTION READY)"
    echo "  🔧 check_roles_simple.sql (diagnostic tool)"
    echo "  🔧 diagnose_tenant_mismatch.sql (diagnostic tool)"
    echo "  📖 CLEANUP_SUMMARY.md (documentation)"
    echo "  📖 one_barn_analysis_summary.md (project analysis)"
    echo "  📖 EXECUTION_GUIDE.md (step-by-step guide)"
    echo ""
    echo "🐎🤖 Ready for testing and production deployment!"
    
else
    echo ""
    echo "❌ Cleanup cancelled."
fi 