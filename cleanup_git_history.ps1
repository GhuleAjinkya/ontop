# PowerShell script to safely clean MongoDB credentials from Git history
# This script uses git-filter-repo to permanently remove sensitive data

# Create a directory for a temporary backup
Write-Host "Creating backup of the repository..."
New-Item -ItemType Directory -Force -Path "../asep_app_backup"
Copy-Item -Recurse -Force "./*" -Destination "../asep_app_backup"
Write-Host "Backup created in ../asep_app_backup"

# Create a regex pattern file for git-filter-repo
$patterns = @(
    # Base64 encoded data that might contain credentials
    '[a-zA-Z0-9+/]{30,}==?',
    
    # MongoDB connection string formats (using more generic patterns)
    'mongodb(\+|-)srv://[^@]+@',
    'mongodb://[^@]+@',
    
    # Any credential patterns with MongoDB clusters
    '[a-zA-Z0-9_-]+[@.]mongodb\.net',
    
    # Generic username:password patterns
    '[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]{8,}@'
)

# Write patterns to a file
$patterns | Out-File -FilePath "./mongo_patterns.txt"
Write-Host "Created pattern file for filtering"

# Use git-filter-repo to clean the history
Write-Host "Running git-filter-repo to remove sensitive data..."
Write-Host "This may take some time depending on the repository size"

# Execute git-filter-repo
git filter-repo --replace-text mongo_patterns.txt

# Clean up
Remove-Item -Force "./mongo_patterns.txt"

Write-Host "Git history cleanup complete!"
Write-Host "IMPORTANT: You need to force push the changes to update the remote repository."
Write-Host "Run: git push --force origin ajinkya"
Write-Host "And remember to change your MongoDB password since the old one was exposed."
