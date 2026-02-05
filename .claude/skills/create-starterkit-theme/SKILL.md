---
name: create-starterkit-theme
description: Create and install a custom Drupal theme using the Starterkit theme generator via DDEV.
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Task
---

# Create Starterkit Theme

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Instructions

1. **Determine the theme name and settings automatically:**
   - Check if `REQUIREMENTS.md` has a "Theme Definition" or "Theme Configuration" section. If it does, parse the theme name (machine name) and any additional settings (theme label, description, base theme, etc.).
   - If no theme definition exists in `REQUIREMENTS.md`, automatically generate theme settings from the Target Site URL in section "0. Target Site":
     - Extract the domain name from the Target Site URL (e.g., "www.jnj.com" → "jnj")
     - Generate theme machine name: `<domain>_custom_theme` (e.g., `jnj_custom_theme`)
     - Generate theme label: `<Domain> Custom Theme` (e.g., `J&J Custom Theme`)
     - Generate description: `Custom theme for <Domain> Drupal site` (e.g., `Custom theme for Johnson & Johnson Drupal site`)
   - If the Target Site section is also missing, use generic defaults:
     - Machine name: `custom_theme`
     - Label: `Custom Theme`
     - Description: `Custom theme generated from starterkit`

2. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-create-starterkit-theme-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

3. **Generate the starterkit theme:**
   - Use the Drupal core generate-theme script (NOTE: `drush theme:generate` does NOT exist in Drupal 11.3.2/Drush 13.x):
     ```
     ddev exec php /var/www/html/web/core/scripts/drupal generate-theme <theme_machine_name> --name="<theme_label>" --description="<description>" --path=themes/custom
     ```
   - The generated theme will be placed in `web/themes/custom/<theme_machine_name>`.
   - Verify that the theme directory and files were created successfully by checking for the existence of `<theme_name>.info.yml` file.

4. **Enable the theme:**
   - Enable the newly generated theme using Drush:
     ```
     ddev drush theme:enable <theme_machine_name>
     ```
   - Verify that the theme is enabled by listing all themes (NOTE: use `pm:list`, NOT `theme:list` which does not exist):
     ```
     ddev drush pm:list --type=theme --status=enabled
     ```

5. **Set the theme as the default theme:**
   - Automatically set the theme as the default theme for the site (no user confirmation needed):
     ```
     ddev drush config:set system.theme default <theme_machine_name> -y
     ```
   - Verify the default theme setting:
     ```
     ddev drush config:get system.theme default
     ```

6. **Clear caches:**
   - Clear all caches to ensure the theme is fully recognized:
     ```
     ddev drush cache:rebuild
     ```

7. **Verify the results:**
   - List all themes using `pm:list` to confirm the custom theme is installed and enabled:
     ```
     ddev drush pm:list --type=theme --status=enabled
     ```
   - Verify that the default theme configuration is correct:
     ```
     ddev drush config:get system.theme default
     ```
   - Check that the theme directory exists with expected files:
     ```
     ls -la web/themes/custom/<theme_machine_name>/
     test -f web/themes/custom/<theme_machine_name>/<theme_machine_name>.info.yml
     ```

8. **Output a summary:**
   - Theme name, label, and description.
   - Whether the theme was generated successfully.
   - Whether the theme was enabled.
   - Confirmation that the theme was set as the default theme.
   - Path to the theme directory.
   - Site URL for testing.

9. **If any issues occur**, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
   - A command fails or returns an unexpected error.
   - A command succeeds but the result does not match the expected behavior.
   - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., theme generation errors, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 2: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 3.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 3.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.
