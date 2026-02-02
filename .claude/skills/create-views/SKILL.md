---
name: create-views
description: Create Views (page display + block display) for all content types in the current Drupal site, dynamically discovering content types and their fields.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Task
---

# Create Views for Content Types

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Overview

This skill creates Drupal Views for every content type present on the site. For each content type, it creates:
- **A Views page display** — a full listing page with pager, sorting, and exposed filters.
- **A Views block display** — a compact block showing the most recent items (e.g., 3-5 items), suitable for embedding in sidebars, landing pages, or related content sections.

The skill dynamically discovers all content types and their fields from the running Drupal site. It does NOT hardcode content type machine names, field names, or URL paths.

## Prerequisites

Before running this skill, ensure that:
- Content types and their fields have been created (via `create-content-types`).
- Taxonomy vocabularies and terms have been created (via `create-taxonomies`).
- Dummy content exists (via `create-dummy-content`) so Views can be visually verified.
- Pathauto is configured (via `configure-pathauto`) so Views page paths don't conflict with existing aliases.

If content types do not exist, **stop and inform the user** that the prerequisite skills must be run first. Dummy content and Pathauto are recommended but not strictly required.

## Instructions

### Phase 1: Research

1. Use Context7 MCP to look up the latest Drupal 11 documentation for:
   - The Views module: programmatic creation of View config entities.
   - The structure of a `views.view.*` configuration entity (displays, display options, filters, sorts, fields, pager, path, block settings).
   - How to create Views programmatically via PHP (`\Drupal\views\Entity\View` or config array structure).
   - Available Views plugins: row plugins (`fields`, `entity:node`), style plugins (`default`, `grid`, `html_list`), pager plugins (`full`, `some`), and field formatters for entity reference, media, taxonomy, text, date, and link fields.

### Phase 2: Snapshot

2. **Before making any changes**, take a DDEV snapshot as a restore point:
   ```
   ddev snapshot --name pre-create-views-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 3: Discover Content Types and Fields

3. **Dynamically discover** all content types currently installed on the site. Do NOT hardcode specific machine names.

   ```
   ddev drush php-eval "foreach(\Drupal\node\Entity\NodeType::loadMultiple() as \$t) echo \$t->id().' | '.\$t->label().PHP_EOL;"
   ```

4. For each discovered content type, **inspect its fields** to determine which fields to include in the Views display and which fields can serve as exposed filters or sort criteria:

   ```
   ddev drush php-eval "
   \$content_types = array_keys(\Drupal\node\Entity\NodeType::loadMultiple());
   foreach (\$content_types as \$ct) {
     echo \"=== \$ct ===\" . PHP_EOL;
     \$fields = \Drupal::service('entity_field.manager')->getFieldDefinitions('node', \$ct);
     foreach (\$fields as \$name => \$field) {
       if (strpos(\$name, 'field_') === 0) {
         \$type = \$field->getType();
         \$label = \$field->getLabel();
         \$settings = \$field->getSettings();
         \$target = '';
         if (\$type === 'entity_reference') {
           \$target = ' -> ' . (\$settings['target_type'] ?? '') . ':' . implode(',', \$settings['handler_settings']['target_bundles'] ?? []);
         }
         echo \"  \$name (\$type) [\$label]\$target\" . PHP_EOL;
       }
     }
   }
   "
   ```

5. Also read `REQUIREMENTS.md` to understand the purpose of each content type. Use this context to determine:
   - **Page URL path**: Choose a short, meaningful English path that reflects the content type's purpose (e.g., a news type → `/news`, products → `/products`, careers → `/careers`). Use lowercase, hyphenated paths. Avoid conflicts with Pathauto alias prefixes — the Views page path should be the **listing page** path (e.g., `/news`) while individual nodes use sub-paths (e.g., `/news/article-title`).
   - **Page title**: Use the content type's plural human-readable label or a suitable listing title (e.g., "News & Stories", "Medicinal Products", "Career Opportunities").
   - **Fields to display**: Select the most relevant fields for a listing view. Typically: title (linked), a summary/teaser field, an image/media field, a date field, and one or two taxonomy reference fields.
   - **Exposed filters**: Taxonomy reference fields and list (text) fields make excellent exposed filters. Include them where they exist.
   - **Sort criteria**: Default sort by creation date (newest first). For content types with explicit date fields (e.g., Publication Date, Fiscal Year), use that field instead.
   - **Block item count**: 3-5 items for the block display (no pager).

### Phase 4: Enable Required Modules

6. Ensure the Views and Views UI modules are enabled:
   ```
   ddev drush en views views_ui -y
   ```

   Verify:
   ```
   ddev drush pm:list --status=enabled --type=module | grep -E "views"
   ```

### Phase 5: Create Views

7. **Script execution approach:** Write a PHP script to create all Views programmatically, then execute it via `ddev drush scr`.
   - Write the script to the **project root** (e.g., `create_views.php`), NOT to `/tmp` or any host-only path, because the DDEV container can only access files inside the project directory.
   - Execute via `ddev drush scr /var/www/html/create_views.php` (using the container-side path).
   - Delete the script after successful execution.

8. The PHP script must create a `View` config entity for each discovered content type. **Check if each View already exists before creating it** (use the View ID as key, e.g., `content_type_listing` or `ct_<machine_name>`).

   Each View entity must include **two displays**:

   #### A. Page Display

   - **Display plugin**: `page`
   - **Path**: As determined in step 5 (e.g., `/news`, `/products`, `/careers`).
   - **Title**: As determined in step 5.
   - **Pager**: Full pager, 10 items per page.
   - **Row plugin**: Choose based on the content type:
     - `entity:node` with `teaser` view mode — suitable for most content types as it leverages the configured teaser display.
     - OR `fields` row plugin with individual field renderers — suitable when specific field layout is needed.
     - **Recommendation**: Use `entity:node` with `teaser` view mode as default for consistency. This respects the content type's teaser view display configuration.
   - **Style plugin**: `default` (unformatted list) or `html_list` (HTML list).
   - **Filter criteria**:
     - `status` = published (Boolean, value = 1) — always include.
     - `type` = the content type machine name — always include.
     - **Exposed filters** for taxonomy reference fields and list (text) fields present on the content type. Configure as select dropdowns with "- Any -" option.
   - **Sort criteria**:
     - Primary: A date field if available (e.g., `field_publication_date`, `created`), descending (newest first).
     - Fallback: `created` (node creation date), descending.
   - **No results behavior**: Display a text area message such as "No content available." when the View returns no results.
   - **Menu**: Optionally add a normal menu item under the "Main navigation" menu.

   #### B. Block Display

   - **Display plugin**: `block`
   - **Title**: "Recent [Content Type Label]" or "Latest [Content Type Label]" (e.g., "Recent News", "Latest Career Opportunities").
   - **Pager**: Display a fixed number of items (use `some` pager plugin), 3-5 items.
   - **Row plugin**: Same as page display (use `entity:node` with `teaser` view mode).
   - **Style plugin**: `default` (unformatted list).
   - **Filter criteria**: Same as page display (published + content type).
   - **Sort criteria**: Same as page display (date descending).
   - **No exposed filters** on the block display.
   - **More link**: Enable "More link" pointing to the page display's path, so users can click through to the full listing.

   #### View Configuration Structure Reference

   The View config entity is a nested array structure. Here is a reference for creating Views programmatically:

   ```php
   use Drupal\views\Entity\View;

   $view_id = 'VIEW_MACHINE_NAME';
   $existing = View::load($view_id);
   if ($existing) {
     echo "View '$view_id' already exists. Skipping.\n";
   }
   else {
     $view = View::create([
       'id' => $view_id,
       'label' => 'VIEW HUMAN LABEL',
       'module' => 'views',
       'description' => 'Description of the view.',
       'tag' => '',
       'base_table' => 'node_field_data',
       'base_field' => 'nid',
       'display' => [
         'default' => [
           'display_plugin' => 'default',
           'id' => 'default',
           'display_title' => 'Default',
           'position' => 0,
           'display_options' => [
             'title' => 'PAGE TITLE',
             'fields' => [],  // Only needed if using 'fields' row plugin
             'pager' => [
               'type' => 'full',
               'options' => [
                 'items_per_page' => 10,
                 'offset' => 0,
               ],
             ],
             'sorts' => [
               'created' => [
                 'id' => 'created',
                 'table' => 'node_field_data',
                 'field' => 'created',
                 'order' => 'DESC',
                 'entity_type' => 'node',
                 'plugin_id' => 'date',
               ],
             ],
             'filters' => [
               'status' => [
                 'id' => 'status',
                 'table' => 'node_field_data',
                 'field' => 'status',
                 'value' => '1',
                 'plugin_id' => 'boolean',
                 'entity_type' => 'node',
                 'group' => 1,
               ],
               'type' => [
                 'id' => 'type',
                 'table' => 'node_field_data',
                 'field' => 'type',
                 'value' => ['CONTENT_TYPE' => 'CONTENT_TYPE'],
                 'entity_type' => 'node',
                 'plugin_id' => 'bundle',
                 'group' => 1,
               ],
             ],
             'filter_groups' => [
               'operator' => 'AND',
               'groups' => [1 => 'AND'],
             ],
             'style' => [
               'type' => 'default',
             ],
             'row' => [
               'type' => 'entity:node',
               'options' => [
                 'view_mode' => 'teaser',
               ],
             ],
             'empty' => [
               'area_text_custom' => [
                 'id' => 'area_text_custom',
                 'table' => 'views',
                 'field' => 'area_text_custom',
                 'plugin_id' => 'text_custom',
                 'content' => 'No content available.',
               ],
             ],
             'access' => [
               'type' => 'perm',
               'options' => [
                 'perm' => 'access content',
               ],
             ],
             'cache' => [
               'type' => 'tag',
             ],
             'query' => [
               'type' => 'views_query',
             ],
           ],
         ],
         'page_1' => [
           'display_plugin' => 'page',
           'id' => 'page_1',
           'display_title' => 'Page',
           'position' => 1,
           'display_options' => [
             'path' => 'PAGE_PATH',
             // Exposed filters override for page display
             // Additional display-specific overrides go here
           ],
         ],
         'block_1' => [
           'display_plugin' => 'block',
           'id' => 'block_1',
           'display_title' => 'Block',
           'position' => 2,
           'display_options' => [
             'title' => 'Recent CONTENT_TYPE_LABEL',
             'pager' => [
               'type' => 'some',
               'options' => [
                 'items_per_page' => 5,
                 'offset' => 0,
               ],
             ],
             'defaults' => [
               'title' => FALSE,
               'pager' => FALSE,
               'use_more' => FALSE,
               'use_more_always' => FALSE,
               'link_url' => FALSE,
             ],
             'use_more' => TRUE,
             'use_more_always' => TRUE,
             'link_url' => 'PAGE_PATH',
           ],
         ],
       ],
     ]);
     $view->save();
     echo "Created View: $view_id\n";
   }
   ```

   **Important:**
   - Research the exact View config structure via Context7 to confirm field names and plugin IDs. The example above is a reference; the actual structure may differ slightly depending on the Drupal core version.
   - For **exposed filters** on taxonomy reference fields, use the `taxonomy_index_tid` filter plugin (for single-vocabulary fields) or the appropriate entity reference filter. Set `'exposed' => TRUE` and provide `'expose'` options with label, identifier, and operator.
   - For taxonomy exposed filters, the filter definition typically looks like:
     ```php
     'FIELD_NAME_target_id' => [
       'id' => 'FIELD_NAME_target_id',
       'table' => 'node__FIELD_NAME',
       'field' => 'FIELD_NAME_target_id',
       'value' => [],
       'exposed' => TRUE,
       'expose' => [
         'operator_id' => 'FIELD_NAME_target_id_op',
         'label' => 'Filter Label',
         'identifier' => 'FIELD_NAME',
         'remember' => FALSE,
         'reduce' => FALSE,
       ],
       'plugin_id' => 'taxonomy_index_tid',
       'vid' => 'VOCABULARY_ID',
       'type' => 'select',
       'hierarchy' => FALSE,
       'group' => 1,
     ],
     ```
   - For list (text) exposed filters:
     ```php
     'FIELD_NAME_value' => [
       'id' => 'FIELD_NAME_value',
       'table' => 'node__FIELD_NAME',
       'field' => 'FIELD_NAME_value',
       'value' => [],
       'exposed' => TRUE,
       'expose' => [
         'operator_id' => 'FIELD_NAME_value_op',
         'label' => 'Filter Label',
         'identifier' => 'FIELD_NAME',
         'remember' => FALSE,
         'reduce' => FALSE,
       ],
       'plugin_id' => 'list_field',
       'group' => 1,
     ],
     ```

### Phase 6: Configure Teaser View Mode (if needed)

9. If the teaser view mode for any content type does not have custom fields configured (i.e., all fields are hidden), configure a basic teaser display so the Views output shows meaningful content:

   ```
   ddev drush php-eval "
   \$content_types = array_keys(\Drupal\node\Entity\NodeType::loadMultiple());
   foreach (\$content_types as \$ct) {
     \$display = \Drupal\Core\Entity\Entity\EntityViewDisplay::load('node.' . \$ct . '.teaser');
     if (\$display) {
       \$components = \$display->getComponents();
       \$custom_fields = array_filter(array_keys(\$components), fn(\$k) => strpos(\$k, 'field_') === 0);
       echo \$ct . ': ' . count(\$custom_fields) . ' custom fields in teaser' . PHP_EOL;
     } else {
       echo \$ct . ': NO teaser display configured' . PHP_EOL;
     }
   }
   "
   ```

   For content types without a teaser display or with no custom fields in teaser, create or update the teaser `EntityViewDisplay` to show a meaningful subset of fields (e.g., an image/media field, a summary/text field, and a date field). Use the same approach as the `create-content-types` skill's view display configuration.

### Phase 7: Verification

10. Verify that all Views were created successfully:
    ```
    ddev drush php-eval "
    \$views = \Drupal\views\Entity\View::loadMultiple();
    foreach (\$views as \$view) {
      \$displays = array_keys(\$view->get('display'));
      echo \$view->id() . ' (' . \$view->label() . '): ' . implode(', ', \$displays) . PHP_EOL;
    }
    "
    ```

11. For each created View, verify it has both a page and block display:
    ```
    ddev drush php-eval "
    \$view = \Drupal\views\Entity\View::load('VIEW_ID');
    if (\$view) {
      \$displays = \$view->get('display');
      foreach (\$displays as \$id => \$display) {
        echo \$id . ': ' . \$display['display_plugin'] . ' - ' . (\$display['display_options']['path'] ?? 'N/A') . PHP_EOL;
      }
    }
    "
    ```

12. Verify the page displays are accessible by requesting each page path:
    ```
    ddev drush php-eval "
    \$views = \Drupal\views\Entity\View::loadMultiple();
    foreach (\$views as \$view) {
      foreach (\$view->get('display') as \$id => \$display) {
        if (\$display['display_plugin'] === 'page') {
          \$path = \$display['display_options']['path'] ?? '';
          if (\$path) {
            echo \$view->id() . ' page: /' . \$path . PHP_EOL;
          }
        }
      }
    }
    "
    ```

    Then test a few pages via curl or `ddev drush eval` to confirm they render without errors:
    ```
    ddev exec curl -s -o /dev/null -w "%{http_code}" http://localhost/PAGE_PATH
    ```

13. Verify that block displays are available in the block system:
    ```
    ddev drush php-eval "
    \$definitions = \Drupal::service('plugin.manager.block')->getDefinitions();
    foreach (\$definitions as \$id => \$def) {
      if (strpos(\$id, 'views_block:') === 0) {
        echo \$id . ' => ' . \$def['admin_label'] . PHP_EOL;
      }
    }
    "
    ```

14. Clear all caches after creating Views:
    ```
    ddev drush cr
    ```

15. Output a summary:
    - List of created Views (ID, label, page path, block display name).
    - Which Views already existed and were skipped.
    - Whether teaser displays were updated for any content types.
    - Any errors encountered during creation.

### Phase 8: Cleanup and Documentation

16. Delete the PHP script from the project root after successful execution.

17. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - A View was created but the page returns an error or empty results unexpectedly.
    - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., View creation errors, site becomes unstable):

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
