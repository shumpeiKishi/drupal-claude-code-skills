---
name: create-base-layout
description: Create a clean, semantic base layout for a Drupal theme by overriding page.html.twig and minimizing theme regions.
disable-model-invocation: false
allowed-tools: Bash, Read, Write, Edit, Grep
---

# Create Base Layout

## Context

This skill creates a clean, semantic base layout for a Drupal theme by:
1. Overriding the default `page.html.twig` template with a simple, component-friendly structure
2. Minimizing theme regions in the `.info.yml` file to only essential regions (header, content, footer)

This is typically done to create a clean slate for component-based theming with SDC (Single Directory Components) or modern frontend frameworks, removing unnecessary complexity from Drupal's default templates.

## Instructions

### Phase 1: Snapshot

1. **Before making any changes**, take a DDEV snapshot as a restore point:
   ```
   ddev snapshot --name pre-create-base-layout-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 2: Discover Current State

2. **Identify the active theme**:
   ```
   ddev drush config-get system.theme default
   ```
   Record the machine name of the current default theme. This theme will be used for all subsequent operations.

3. **Locate the theme directory**:
   ```
   find web/themes/custom -type d -name "<theme_machine_name>"
   ```
   Verify that the theme directory exists. The path should be `web/themes/custom/<theme_machine_name>`.

4. **Check if page.html.twig already exists** in the theme:
   ```
   test -f web/themes/custom/<theme_machine_name>/templates/layout/page.html.twig && echo "EXISTS" || echo "NOT_FOUND"
   ```
   If it exists, read it to preserve any custom modifications that should be retained.

### Phase 3: Create page.html.twig Template

5. **Create the templates/layout directory** if it doesn't exist:
   ```
   mkdir -p web/themes/custom/<theme_machine_name>/templates/layout
   ```

6. **Create the clean, semantic page.html.twig template**:
   - Write the following template to `web/themes/custom/<theme_machine_name>/templates/layout/page.html.twig`:

   ```twig
   {#
   /**
    * @file
    * Theme override to display a single page.
    *
    * This is a clean, semantic layout designed for component-based theming.
    * The layout uses Tailwind CSS utility classes for structure.
    *
    * Available variables:
    * - page: The page render array with regions.
    */
   #}
   <div class="site-wrapper flex min-h-screen flex-col">
     <header class="site-header">
       {{ page.header }}
     </header>

     <main class="site-main grow">
       {# Container with max-width and padding for content #}
       <div class="container mx-auto px-4 py-8">
         {{ page.content }}
       </div>
     </main>

     <footer class="site-footer">
       {{ page.footer }}
     </footer>
   </div>
   ```

   **Note:** This template assumes Tailwind CSS is available. If Tailwind is not set up, the utility classes will have no effect but won't break the layout. The semantic HTML structure will still be clean and usable.

### Phase 4: Minimize Theme Regions

7. **Read the current .info.yml file**:
   ```
   cat web/themes/custom/<theme_machine_name>/<theme_machine_name>.info.yml
   ```
   Check if a `regions:` section already exists. If it exists, note the current regions for reference.

8. **Determine the minimal regions configuration**:
   - For component-based theming with SDC, only three essential regions are needed:
     - `header`: For header components and any header blocks
     - `content`: For main page content (required by Drupal)
     - `footer`: For footer components and any footer blocks

   - Optional regions that may be added based on project needs:
     - `breadcrumb`: If breadcrumbs are needed
     - `highlighted`: For messages, tabs, and admin actions blocks
     - `help`: For contextual help blocks
     - `sidebar_first`: If a sidebar layout is required
     - `sidebar_second`: If a two-sidebar layout is required

9. **Apply minimal regions to .info.yml**:
   - If a `regions:` section already exists in the .info.yml file, replace it with the minimal configuration.
   - If no `regions:` section exists, add it to the end of the file.
   - The minimal regions configuration to add:

   ```yaml
   regions:
     header: 'Header'
     content: 'Content'
     footer: 'Footer'
   ```

   **Note:** If essential blocks (messages, tabs, admin actions) are enabled and need a region, add `highlighted: 'Highlighted'` to the regions list and update the `page.html.twig` template to include `{{ page.highlighted }}` before the `<main>` tag.

10. **For themes with existing blocks**, check if essential blocks need the `highlighted` region:
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$blocks = \Drupal::entityTypeManager()->getStorage('block')->loadByProperties(['theme' => \$theme, 'status' => TRUE]);
    \$needs_highlighted = FALSE;
    foreach (\$blocks as \$block) {
      \$plugin_id = \$block->getPluginId();
      if (in_array(\$plugin_id, ['system_messages_block', 'local_tasks_block', 'local_actions_block'])) {
        \$needs_highlighted = TRUE;
        echo 'Found essential block: ' . \$block->label() . ' (' . \$plugin_id . ')' . PHP_EOL;
      }
    }
    echo \$needs_highlighted ? 'HIGHLIGHTED_NEEDED' : 'HIGHLIGHTED_NOT_NEEDED';
    "
    ```

    If `HIGHLIGHTED_NEEDED` is returned:
    - Add `highlighted: 'Highlighted'` to the regions in .info.yml
    - Update page.html.twig to include the highlighted region:

    ```twig
    <div class="site-wrapper flex min-h-screen flex-col">
      <header class="site-header">
        {{ page.header }}
      </header>

      {# Highlighted region for messages, tabs, and admin actions #}
      {% if page.highlighted %}
        <div class="highlighted">
          {{ page.highlighted }}
        </div>
      {% endif %}

      <main class="site-main grow">
        {# Container with max-width and padding for content #}
        <div class="container mx-auto px-4 py-8">
          {{ page.content }}
        </div>
      </main>

      <footer class="site-footer">
        {{ page.footer }}
      </footer>
    </div>
    ```

### Phase 5: Clear Caches and Verify

11. **Clear all caches** to ensure the template and region changes are recognized:
    ```
    ddev drush cr
    ```

12. **Verify the template file exists**:
    ```
    test -f web/themes/custom/<theme_machine_name>/templates/layout/page.html.twig && echo "TEMPLATE_EXISTS" || echo "TEMPLATE_MISSING"
    ```

13. **Verify theme regions**:
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$theme_handler = \Drupal::service('theme_handler');
    \$theme_object = \$theme_handler->getTheme(\$theme);
    \$regions = \$theme_object->info['regions'] ?? [];
    echo 'Theme regions after update:' . PHP_EOL;
    foreach (\$regions as \$key => \$label) {
      echo '  - ' . \$key . ': ' . \$label . PHP_EOL;
    }
    "
    ```

    Expected output should show only the minimal regions (header, content, footer, and optionally highlighted).

14. **Check for any orphaned blocks** (blocks assigned to regions that no longer exist):
    ```
    ddev drush php-eval "
    \$theme = \Drupal::config('system.theme')->get('default');
    \$theme_handler = \Drupal::service('theme_handler');
    \$theme_object = \$theme_handler->getTheme(\$theme);
    \$valid_regions = array_keys(\$theme_object->info['regions'] ?? []);
    \$blocks = \Drupal::entityTypeManager()->getStorage('block')->loadByProperties(['theme' => \$theme]);
    \$orphaned = [];
    foreach (\$blocks as \$block) {
      \$region = \$block->getRegion();
      if (!\in_array(\$region, \$valid_regions, TRUE)) {
        \$orphaned[] = \$block->label() . ' (region: ' . \$region . ')';
      }
    }
    if (!empty(\$orphaned)) {
      echo 'WARNING: Orphaned blocks found:' . PHP_EOL;
      foreach (\$orphaned as \$block_info) {
        echo '  - ' . \$block_info . PHP_EOL;
      }
    } else {
      echo 'No orphaned blocks found.' . PHP_EOL;
    }
    "
    ```

    **Note:** Orphaned blocks will be disabled automatically by Drupal. If you need to keep any of these blocks, manually update their region assignments via the Block layout UI or programmatically.

### Phase 6: Output Summary

15. Output a summary:
    - Theme name and path
    - Template file location: `web/themes/custom/<theme_machine_name>/templates/layout/page.html.twig`
    - Regions configured in .info.yml
    - Whether the `highlighted` region was added (if essential blocks were found)
    - Any orphaned blocks that were detected
    - Snapshot name for rollback if needed
    - Site URL for testing (e.g., `ddev describe` to get the URL)

16. **If any issues occur**, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - Template file could not be created or written
    - .info.yml file could not be edited
    - Regions configuration caused unexpected behavior
    - Blocks became orphaned unexpectedly
    - Cache clearing failed
    - Troubleshooting or retry was required to complete a step

## Retry and Rollback Policy

If a step in the process fails (e.g., template errors, region configuration issues, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 1: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 2.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 2.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.

## Notes

- This skill is designed to work with any custom Drupal theme, regardless of its name or base theme.
- The template uses Tailwind CSS utility classes, but will work without Tailwind (the classes will simply have no effect).
- For projects using SDC (Single Directory Components), this clean base layout provides a minimal foundation where most UI is built through components rather than blocks.
- If you need additional regions (e.g., breadcrumb, help, sidebars), add them to the .info.yml file and update the page.html.twig template accordingly.
- The `highlighted` region is conditionally added only if essential blocks (messages, tabs, admin actions) are detected. For a truly minimal setup, run the `cleanup-block-layout` skill first to disable non-essential blocks.
