---
name: create-content-types
description: Create all content types and their fields defined in REQUIREMENTS.md using Drush commands via DDEV.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Task
---

# Create Content Types and Fields

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Important: Media Usage for Image and File Fields

**All image and file fields MUST use Drupal's Media system (Media module) instead of plain File or Image field types.**

- Use `entity_reference` fields referencing the `media` entity type, NOT `file` or `image` field types.
- When creating fields for images (e.g., Product Logo, Headshot, Featured Media, Earnings Infographic, Hero Component), use a media reference field filtered to the "Image" media type.
- When creating fields for documents/files (e.g., IFU PDF, Data Download PDF/Excel), use a media reference field filtered to the "Document" media type.
- When creating fields for videos or multimedia (e.g., 3D Model Embed), use a media reference field filtered to the appropriate media type (e.g., "Video", "Remote video").
- Ensure the Media module and its related sub-modules (`media_library`) are enabled before creating any media reference fields.

**Rationale:** Media entities provide reusable assets, centralized management, and better editorial UX via the Media Library widget. Using plain file/image fields is NOT acceptable for this project.

## Instructions

1. Parse the "1. Content Type Definitions" section from the requirements above. Identify every content type (machine name), its description, and its key custom fields.

2. Also review the "3. Implementation Strategy" section for additional field requirements (e.g., required fields, specific display placement, audience gating integration).

3. Use Context7 MCP to look up the latest Drupal 11 / Drush documentation for content type and field creation. Confirm the correct Drush commands and options. In particular, research:
   - How to create content types via Drush (`drush php-eval` with `NodeType` entity or config import).
   - How to create fields (`FieldStorageConfig`, `FieldConfig`) via Drush.
   - How to create media reference fields with specific media type restrictions.
   - How to configure form display (`EntityFormDisplay`) and view display (`EntityViewDisplay`) programmatically.

4. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-create-content-types-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

5. **Enable required modules** before creating content types and fields:
   - Ensure `node`, `field`, `text`, `options`, `link`, `media`, `media_library` and any other necessary modules are enabled.
   - Run `ddev drush pm:list --status=enabled` to verify.

6. **Script execution approach:** When running complex Drupal API operations (content type creation, field creation, display configuration, etc.), write a PHP script file and execute it via `ddev drush scr`.
   - Write the script to the **project root** (e.g., `create_content_types.php`), NOT to `/tmp` or any host-only path, because the DDEV container can only access files inside the project directory.
   - Execute via `ddev drush scr /var/www/html/<script_name>.php` (using the container-side path).
   - Delete the script after execution to keep the project root clean.

7. For each content type defined in the requirements, run via `ddev drush`:
   - Check if the content type already exists. If not, create it with its **description** set.
   - For each field under the content type:
     - Determine the appropriate field type based on the field's purpose:
       - **Text fields** (short text, long text, formatted text) for names, titles, descriptions, bios, lead text, etc.
       - **Link fields** for URLs (Prescribing Info Link, Application URL, LinkedIn URL).
       - **List (text) or taxonomy reference fields** for selectable options (Fiscal Year, Quarter, Filing Type, Employment Type, Job Function, etc.). If the options map to a taxonomy vocabulary defined in the requirements, use an entity reference to that vocabulary.
       - **Entity reference (media)** for ALL images, files, documents, videos, and multimedia content. See the "Media Usage" section above. **Never use plain `image` or `file` field types.**
       - **Entity reference (taxonomy)** for taxonomy-based categorization fields (Therapeutic Area, Related Tags, Clinical Category, etc.).
       - **Boolean or list fields** for simple toggles or constrained choices.
     - Check if the field storage already exists. If not, create it.
     - Check if the field instance is already attached to the content type. If not, create it with the appropriate **label**, **description**, and **settings** (required flag, cardinality, target bundles for entity references, etc.).
   - **Field rules:**
     - Follow the "Implementation Strategy" notes: e.g., "Boxed Warning" and "ISI" in `medicinal_product` must be **required** fields.
     - Use the description provided in `REQUIREMENTS.md`. If no explicit description is given, infer an appropriate description from the field name and surrounding context.

8. **Configure form display (`EntityFormDisplay`)** for each content type so that all custom fields are visible and editable on the node add/edit form.

   For each content type, load or create the `EntityFormDisplay` for the `default` form mode and set the appropriate widget for each field:

   - **Media reference fields** (e.g., Product Logo, Headshot, Featured Media, IFU PDF, Data Download, Earnings Infographic, Hero Component): Use the `media_library_widget` widget type. This provides the Media Library UI for selecting/uploading media.
   - **Entity reference (taxonomy) fields** (e.g., Therapeutic Area, Clinical Category, Related Tags): Use `options_select` (for single-value) or `entity_reference_autocomplete` (for multi-value with many terms). Choose based on the expected number of terms.
   - **Entity reference (node) fields** (e.g., Author Profile): Use `entity_reference_autocomplete`.
   - **Text (long/formatted) fields** (e.g., Boxed Warning, ISI, Biography, Technical Specs, Lead Text, etc.): Use `text_textarea`.
   - **String fields** (e.g., Title/Position, Location, Committee Memberships): Use `string_textfield`.
   - **String (long) fields** (e.g., Meta Tags): Use `string_textarea`.
   - **Link fields** (e.g., Prescribing Info Link, LinkedIn URL, Application URL): Use `link_default`.
   - **List (text) fields** (e.g., Fiscal Year, Quarter, Filing Type, Employment Type, Job Function): Use `options_select`.
   - **Datetime fields** (e.g., Publication Date): Use `datetime_default`.

   Assign incremental **weight** values to control field ordering on the form. Place more important/required fields first (lower weight).

   Example pattern:
   ```php
   use Drupal\Core\Entity\Entity\EntityFormDisplay;

   $form_display = EntityFormDisplay::load('node.BUNDLE.default');
   if (!$form_display) {
     $form_display = EntityFormDisplay::create([
       'targetEntityType' => 'node',
       'bundle' => 'BUNDLE',
       'mode' => 'default',
       'status' => TRUE,
     ]);
   }
   $form_display->setComponent('field_name', [
     'type' => 'WIDGET_TYPE',
     'weight' => WEIGHT,
     'settings' => [],
     'third_party_settings' => [],
   ]);
   $form_display->save();
   ```

9. **Configure view display (`EntityViewDisplay`)** for each content type so that all custom fields are rendered on the front-end node page.

   For each content type, load or create the `EntityViewDisplay` for the `default` view mode and set the appropriate formatter for each field:

   - **Media reference fields**: Use `entity_reference_entity_view` formatter (renders the referenced media entity, e.g., the image). Set the `view_mode` setting to `default` or a specific media view mode.
   - **Entity reference (taxonomy) fields**: Use `entity_reference_label` formatter (renders term names as links).
   - **Entity reference (node) fields**: Use `entity_reference_label` formatter.
   - **Text (long/formatted) fields**: Use `text_default` formatter.
   - **String fields**: Use `string` formatter.
   - **String (long) fields**: Use `basic_string` formatter.
   - **Link fields**: Use `link` formatter.
   - **List (text) fields**: Use `list_default` formatter.
   - **Datetime fields**: Use `datetime_default` formatter.

   Set the **label** display to `above` (label shown above the field value) for most fields. For media/hero fields, `hidden` may be more appropriate.

   Assign incremental **weight** values to control field ordering on the rendered page.

   Example pattern:
   ```php
   use Drupal\Core\Entity\Entity\EntityViewDisplay;

   $view_display = EntityViewDisplay::load('node.BUNDLE.default');
   if (!$view_display) {
     $view_display = EntityViewDisplay::create([
       'targetEntityType' => 'node',
       'bundle' => 'BUNDLE',
       'mode' => 'default',
       'status' => TRUE,
     ]);
   }
   $view_display->setComponent('field_name', [
     'type' => 'FORMATTER_TYPE',
     'weight' => WEIGHT,
     'label' => 'above',
     'settings' => [],
     'third_party_settings' => [],
   ]);
   $view_display->save();
   ```

10. After all operations, verify the results:
   - List all content types to confirm creation, including their descriptions.
   - For each content type, list its fields to confirm they are correctly configured.
   - For each content type, verify that the form display has all custom fields with widgets configured (not hidden).
   - For each content type, verify that the view display has all custom fields with formatters configured (not hidden).

11. Output a summary: which content types/fields were created, which already existed, and confirm that form display and view display are configured for all fields.

12. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
   - A command fails or returns an unexpected error.
   - A command succeeds but the result does not match the expected behavior.
   - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., content type/field creation errors, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 4: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 5.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 5.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.
