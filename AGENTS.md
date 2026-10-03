# Maintain README and Release Notes Rule

When working in this repository:
1. If you add a new feature, change an existing feature's behavior, or modify the installation/usage instructions, you MUST also update `README.md` to reflect these changes.
2. Keep the README concise, user-friendly, and accurate.
3. Always verify that cross-platform (Windows & macOS) differences are accurately documented.
4. **Versioning & Release Notes**: When you make new code/feature updates and push them to GitHub, you MUST update `RELEASE_NOTES.md` with a new section and incremented version number.
   - Use Semantic Versioning: Increment the Major version (e.g., 1.0 -> 2.0) if the change was substantial or breaking, or the Minor version (e.g., 1.0 -> 1.1) if it was a smaller feature or bug fix.
   - You MUST also increment the `$AppVersion` variable near the top of `note.ps1` to match the new version.
   - **Note:** README-only or documentation-only updates do NOT require updating `$AppVersion` or adding release notes.
