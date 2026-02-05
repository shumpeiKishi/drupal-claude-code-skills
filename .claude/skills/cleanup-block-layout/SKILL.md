---
name: cleanup-block-layout
description: Clean up Drupal block layout by disabling all non-essential blocks and verifying theme regions are minimal.
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Grep
---

# Cleanup Block Layout

## Context

This skill cleans up the Drupal block layout by:
1. Disabling all blocks except essential core blocks (Main page content, Messages, Tabs, Primary admin actions)
2. Verifying that the custom theme has minimal regions defined

This is typically done to create a clean slate for component-based theming with SDC (Single Directory Components) or headless/decoupled approaches.

**Note:** `local_actions_block` (Primary admin actions) is kept enabled for better administrative UX. This block displays action buttons like "Add content" on admin pages.

## Instructions

### Phase 1: Research

1. Use Context7 MCP to look up the latest Drupal 11 documentation for:
   - Block configuration via Drush
   - Block placement and configuration entities
   - Theme regions and .info.yml configuration
   - How to disable blocks programmatically

### Phase 2: Snapshot

2. **Before making any changes**, take a DDEV snapshot as a restore point:
   ```
   ddev snapshot --name pre-cleanup-blocks-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 3: Discover Current State

3. **Identify the active theme**:
   ```
   ddev drush config-get system.theme default
   ```
   Record the machine name of the current default theme.

4. **List all block configurations** for the current theme:
   ```
   ddev drush php-eval "
   \$theme = \Drupal::config('system.theme')->get('default');
   \$blocks = \Drupal::entityTypeManager()->getStorage('block')->loadByProperties(['theme' => \$theme]);
   foreach (\$blocks as \$block) {
     \$status = \$block->status() ? 'enabled' : 'disabled';
     echo \$block->id() . ' | ' . \$block->label() . ' | ' . \$block->getRegion() . ' | ' . \$status . PHP_EOL;
   }
   "
   ```

5. **Identify essential blocks** to keep enabled:
   - Main page content (plugin ID: `system_main_block`)
   - Messages (plugin ID: `system_messages_block`)
   - Tabs (plugin ID: `local_tasks_block` - includes both primary and secondary tabs)
   - Primary admin actions (plugin ID: `local_actions_block` - displays "Add content" etc. buttons for better admin UX)

### Phase 4: Disable Non-Essential Blocks

6. **Script execution approach:** Write a PHP script to disable all non-essential blocks, then execute it via `ddev drush scr`.
   - Write the script to the **project root** (e.g., `cleanup_blocks.php`), NOT to `/tmp` or any host-only path.
   - Execute via `ddev drush scr /var/www/html/cleanup_blocks.php`.
   - Delete the script after successful execution.

7. The PHP script must:
   - Load all block configurations for the current theme.
   - Identify essential blocks (Main page content, Messages, Tabs, Primary admin actions) by checking block plugin IDs.
   - Disable all other blocks by setting `status: false` and saving the configuration.
   - Output a summary of which blocks were disabled and which were kept enabled.

   **Note:** The script should be run BEFORE changing theme regions to avoid unexpected block re-activation.

   **Example PHP script structure:**
   ```php
   <?php

   use Drupal\block\Entity\Block;

   // Get the current default theme.
   $theme = \Drupal::config('system.theme')->get('default');
   echo "Current theme: $theme\n\n";

   // Define essential block plugin IDs or patterns.
   // These blocks should remain enabled.
   $essential_patterns = [
     'system_main_block',         // Main page content
     'system_messages_block',     // Messages
     'local_tasks_block',         // Tabs (primary/secondary)
     'local_actions_block',       // Primary admin actions (Add content, etc.)
   ];

   // Load all blocks for the current theme.
   $blocks = \Drupal::entityTypeManager()
     ->getStorage('block')
     ->loadByProperties(['theme' => $theme]);

   $disabled_count = 0;
   $kept_count = 0;

   foreach ($blocks as $block) {
     $plugin_id = $block->getPluginId();
     $label = $block->label();
     $is_essential = FALSE;

     // Check if this block matches any essential pattern.
     foreach ($essential_patterns as $pattern) {
       if (strpos($plugin_id, $pattern) !== FALSE) {
         $is_essential = TRUE;
         break;
       }
     }

     if ($is_essential) {
       // Keep essential blocks enabled.
       if (!$block->status()) {
         $block->enable()->save();
         echo "Enabled: $label ($plugin_id)\n";
       }
       else {
         echo "Kept: $label ($plugin_id)\n";
       }
       $kept_count++;
     }
     else {
       // Disable non-essential blocks.
       if ($block->status()) {
         $block->disable()->save();
         echo "Disabled: $label ($plugin_id)\n";
         $disabled_count++;
       }
       else {
         // Already disabled, skip.
       }
     }
   }

   echo "\nSummary:\n";
   echo "- Essential blocks kept enabled: $kept_count\n";
   echo "- Non-essential blocks disabled: $disabled_count\n";
   ```

### Phase 5: Verify Theme Regions

8. **Find the custom theme's .info.yml file**:
   ```
   find web/themes/custom -name "*.info.yml"
   ```

9. **Read the .info.yml file** and check the `regions:` section.
   - If no `regions:` section is defined, the theme inherits regions from its base theme (typically 12 default regions from Drupal core).
   - For component-based theming with SDC, a minimal regions definition is recommended.

10. **Determine required regions** based on enabled blocks:
    - Check where essential blocks are currently placed (especially `system_messages_block` and `local_tasks_block` which are typically in the `highlighted` region)
    - The `content` region is mandatory (for `system_main_block`)
    - The `highlighted` region is required if messages/tabs blocks are placed there

11. **Apply minimal regions configuration:**
    - Inform the user about the change: "Applying minimal regions to .info.yml based on enabled blocks..."
    - For a practical minimal setup that supports essential blocks:
      ```yaml
      regions:
        header: 'Header'
        highlighted: 'Highlighted'
        content: 'Content'
        footer: 'Footer'
      ```
    - **Rationale:**
      - `header`: For future header components
      - `highlighted`: Required for messages, tabs, and admin actions blocks
      - `content`: Required for main page content
      - `footer`: For future footer components
    - Edit the .info.yml file to add the `regions:` section with the minimal configuration shown above.

12. **Clear caches** after modifying the .info.yml file:
    ```
    ddev drush cr
    ```

### Phase 5.5: Post-Region-Change Verification

**IMPORTANT:** After changing theme regions and clearing caches, Drupal may re-evaluate block placements and potentially re-enable or re-configure certain blocks.

13. **Verify block status** after region changes:
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$blocks = \Drupal::entityTypeManager()->getStorage('block')->loadByProperties(['theme' => \$theme]);
    echo 'Block status after region changes:' . PHP_EOL;
    foreach (\$blocks as \$block) {
      \$status = \$block->status() ? 'ENABLED' : 'disabled';
      echo '  [' . \$status . '] ' . \$block->label() . ' (' . \$block->getPluginId() . ') in region: ' . \$block->getRegion() . PHP_EOL;
    }
    "
    ```

14. **Check for unexpected changes**:
    - Compare the output with the expected state (essential blocks enabled, others disabled)
    - If any blocks were unexpectedly re-enabled or disabled, correct their status manually
    - Document any unexpected behavior in `RETROSPECTIVE.md`

15. **Re-enable or re-disable blocks if needed**:
    ```bash
    # Example: Re-enable a block
    ddev drush php-eval "\$block = \Drupal::entityTypeManager()->getStorage('block')->load('BLOCK_ID'); \$block->enable()->save();"

    # Example: Re-disable a block
    ddev drush php-eval "\$block = \Drupal::entityTypeManager()->getStorage('block')->load('BLOCK_ID'); \$block->disable()->save();"
    ```

### Phase 6: Final Verification

16. **List all enabled blocks** to confirm only essential blocks remain:
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$blocks = \Drupal::entityTypeManager()->getStorage('block')->loadByProperties(['theme' => \$theme, 'status' => TRUE]);
    echo 'Final enabled blocks:' . PHP_EOL;
    foreach (\$blocks as \$block) {
      echo '  - ' . \$block->label() . ' (' . \$block->getPluginId() . ') in region: ' . \$block->getRegion() . PHP_EOL;
    }
    "
    ```

17. **Verify theme regions**:
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$theme_handler = \Drupal::service('theme_handler');
    \$theme_object = \$theme_handler->getTheme(\$theme);
    \$regions = \$theme_object->info['regions'] ?? [];
    echo 'Theme regions:' . PHP_EOL;
    foreach (\$regions as \$key => \$label) {
      echo '  - ' . \$key . ': ' . \$label . PHP_EOL;
    }
    "
    ```

18. Output a summary:
    - Number of blocks disabled
    - Number of essential blocks kept enabled (should be 5: Main page content, Status messages, Primary admin actions, Primary tabs, Secondary tabs)
    - List of enabled blocks with their regions
    - Current theme regions (should be 4: header, highlighted, content, footer)
    - Snapshot name for rollback if needed

### Phase 7: Cleanup and Documentation

19. Delete the PHP script from the project root after successful execution.

20. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - A block could not be disabled due to dependency constraints.
    - Troubleshooting or retry was required to complete a step.
    - **Blocks were unexpectedly re-enabled or re-configured after changing theme regions** (document which blocks, their plugin IDs, and how the issue was resolved)

## Retry and Rollback Policy

If a step in the process fails (e.g., block configuration errors, site becomes unstable):

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
