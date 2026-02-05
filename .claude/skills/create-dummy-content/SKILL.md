---
name: create-dummy-content
description: Create dummy content (nodes with images fetched from the Target Site) for all content types defined in REQUIREMENTS.md using Drush commands via DDEV.
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Task, WebFetch, WebSearch
---

# Create Dummy Content

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Overview

This skill creates realistic dummy content for every content type defined in the requirements. It reads the "Target Site" URL from the requirements, fetches real images from that site to use as media assets, registers them in Drupal's Media system, and then creates fully populated nodes referencing those media entities and existing taxonomy terms.

## Prerequisites

Before running this skill, ensure that:
- Taxonomy vocabularies and terms have been created (via `create-taxonomies`).
- Content types and their fields have been created (via `create-content-types`).

If these do not exist, **stop and inform the user** that the prerequisite skills must be run first.

## Data Preservation Directory

All original source data (downloaded images, generated documents, and PHP scripts containing content definitions) **MUST be preserved** in the `dummy-content/` directory at the project root. This directory serves as the single source of truth for all dummy content data and enables:
- Re-running the import without re-fetching images or regenerating content.
- Reviewing and editing the original data before re-import.
- Keeping a clear record of what was imported.

Directory structure:
```
dummy-content/
├── images/          # Downloaded images from the Target Site
├── documents/       # Generated or downloaded PDFs and other documents
└── scripts/         # PHP scripts used to create media entities and nodes
```

**IMPORTANT:** Do NOT delete any files in `dummy-content/` after execution. Only the copied files inside `web/sites/default/files/` are managed by Drupal; the `dummy-content/` directory is the persistent original source.

## Critical: Bash Variable Expansion

**NEVER run inline PHP code containing `$variables` via `ddev exec php -r "..."`.** Bash interprets `$` as shell variable expansion, causing silent failures or "unbound variable" errors.

**Always** write PHP code to a `.php` file in `dummy-content/scripts/` first, then execute it:
```bash
# WRONG — $variables will be expanded by bash:
ddev exec php -r "$file = File::create(...);"

# CORRECT — write to file, then execute:
# 1. Write PHP script to dummy-content/scripts/my_script.php
# 2. Execute via:
ddev drush scr /var/www/html/dummy-content/scripts/my_script.php
```

The same issue applies to `ddev exec bash -c "..."` with `for` loops or any `$variable` references. When a shell script is needed, write it to a `.sh` file first and execute it:
```bash
# WRONG:
ddev exec bash -c 'for f in /path/*.jpg; do cp "$f" ...; done'

# CORRECT:
# 1. Write shell script to dummy-content/scripts/copy_files.sh
# 2. Execute via:
ddev exec bash /var/www/html/dummy-content/scripts/copy_files.sh
```

## Instructions

### Phase 0: Analyze Requirements and Verify Prerequisites

1. Parse the requirements above and extract:
   - The **Target Site URL** from the "Target Site" section (section 0).
   - All **content types** (machine names, descriptions, key custom fields) from the "Content Type Definitions" section.
   - All **taxonomy vocabularies** and their terms from the "Taxonomy Vocabularies and Terms" section.
   - Any **field requirements** from the "Implementation Strategy" section (e.g., required fields, special constraints).

2. Verify that the Drupal site is running:
   ```
   ddev drush status
   ```

3. Verify that the required content types exist by listing all content types:
   ```
   ddev drush php-eval "foreach(\Drupal\node\Entity\NodeType::loadMultiple() as \$t) { echo \$t->id() . ': ' . \$t->label() . PHP_EOL; }"
   ```
   Cross-check against every content type machine name parsed from the requirements. All must exist.

   > **Note:** `ddev drush entity:list node_type` may not be available in all Drush versions. The `php-eval` approach above is the reliable fallback.

4. Verify that taxonomy vocabularies and their terms exist:
   ```
   ddev drush php-eval "foreach(\Drupal\taxonomy\Entity\Vocabulary::loadMultiple() as \$v) { echo \$v->id() . ': ' . \$v->label() . PHP_EOL; }"
   ```
   Also list terms per vocabulary to confirm they are populated:
   ```
   ddev drush php-eval "
   \$vids = ['VOCABULARY_1', 'VOCABULARY_2'];
   foreach (\$vids as \$vid) {
     echo \"=== \$vid ===\" . PHP_EOL;
     \$terms = \Drupal::entityTypeManager()->getStorage('taxonomy_term')->loadByProperties(['vid' => \$vid]);
     foreach (\$terms as \$term) { echo '  ' . \$term->id() . ': ' . \$term->label() . PHP_EOL; }
   }
   "
   ```
   Cross-check against every vocabulary machine name parsed from the requirements.

5. **Inspect actual field definitions** for each content type. Do NOT rely solely on the requirements text — verify the actual Drupal field configuration to understand:
   - `entity_reference` target types and bundles (media:image, media:document, taxonomy_term:VOCAB, node:BUNDLE)
   - `list_string` allowed values
   - `image` fields vs `entity_reference` to media
   - Field cardinality (single vs multi-value)

   ```
   ddev drush php-eval "
   \$content_types = ['MACHINE_NAME_1', 'MACHINE_NAME_2'];
   foreach (\$content_types as \$ct) {
     echo \"=== \$ct ===\" . PHP_EOL;
     \$fields = \Drupal::service('entity_field.manager')->getFieldDefinitions('node', \$ct);
     foreach (\$fields as \$name => \$field) {
       if (strpos(\$name, 'field_') === 0) {
         echo '  ' . \$name . ' (' . \$field->getType() . ')' . PHP_EOL;
       }
     }
   }
   "
   ```

   For entity_reference and list_string fields, also check detailed settings:
   ```
   ddev drush php-eval "
   \$content_types = ['MACHINE_NAME_1', 'MACHINE_NAME_2'];
   foreach (\$content_types as \$ct) {
     \$fields = \Drupal::service('entity_field.manager')->getFieldDefinitions('node', \$ct);
     foreach (\$fields as \$name => \$field) {
       if (strpos(\$name, 'field_') === 0) {
         \$type = \$field->getType();
         \$settings = \$field->getSettings();
         if (\$type === 'entity_reference') {
           \$target = \$settings['target_type'] ?? 'unknown';
           \$bundles = \$settings['handler_settings']['target_bundles'] ?? [];
           echo \$ct . '.' . \$name . ' => entity_reference to ' . \$target . ' [' . implode(', ', \$bundles) . ']' . PHP_EOL;
         } elseif (\$type === 'list_string') {
           // Allowed values are in field storage config
           echo \$ct . '.' . \$name . ' => list_string (check field storage for allowed values)' . PHP_EOL;
         }
       }
     }
   }
   "
   ```

   For list_string allowed values, check the field storage config:
   ```
   ddev drush php-eval "
   \$fields = ['field.storage.node.FIELD_NAME'];
   foreach (\$fields as \$f) {
     \$config = \Drupal::config(\$f);
     \$allowed = \$config->get('settings.allowed_values');
     echo \$f . ': ' . json_encode(array_column(\$allowed, 'value')) . PHP_EOL;
   }
   "
   ```

   Also check available media bundles and their field names:
   ```
   ddev drush php-eval "
   \$bundles = \Drupal::service('entity_type.bundle.info')->getBundleInfo('media');
   foreach (\$bundles as \$id => \$info) {
     echo \$id . ': ' . \$info['label'] . PHP_EOL;
     \$fields = \Drupal::service('entity_field.manager')->getFieldDefinitions('media', \$id);
     foreach (\$fields as \$name => \$field) {
       if (strpos(\$name, 'field_') === 0) {
         echo '  ' . \$name . ' (' . \$field->getType() . ')' . PHP_EOL;
       }
     }
   }
   "
   ```

6. If any prerequisite is missing, **stop execution** and inform the user which prerequisites are not met.

### Phase 1: Snapshot

7. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-create-dummy-content-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 2: Fetch Images from Target Site

8. Using the **Target Site URL** extracted in step 1, crawl the site to find suitable images for each content type that has image/media fields. Use `WebFetch` and/or `WebSearch` to discover image URLs.

   For each content type, determine which fields require media (image, document, video, etc.) based on the field definitions inspected in Phase 0 (not just the requirements text). Then search the Target Site for images that match the content's theme and purpose.

   **Crawl multiple pages** — the homepage alone may not have enough variety. Visit sub-pages relevant to each content type:
   - Product / Innovative Medicine pages for medicinal product images
   - MedTech / Device pages for medical device images
   - Leadership / About pages for person profile headshots
   - Newsroom / Blog pages for article featured images
   - Investor Relations pages for financial report images
   - Careers pages for career-related images

   **Image fetching rules:**
   - Fetch at least **2-3 distinct images per content type** that has image/media reference fields (to use across multiple dummy nodes).
   - Prefer high-quality images (not tiny thumbnails or icons).
   - Prefer original resolution images from S3/CDN sources over resized/cropped URLs containing `/dims4/` or `/resize/` path segments.
   - Only use images from the Target Site or its CDN subdomains.
   - If images cannot be found on the target site directly, use `WebSearch` to find image URLs from the Target Site's domain indexed by search engines.
   - First, create the data preservation directories:
     ```
     mkdir -p dummy-content/images dummy-content/documents dummy-content/scripts
     ```
   - Download each image into `dummy-content/images/` on the **host side** first, then copy it into the DDEV public files directory. Use a shell script for bulk copying (see "Critical: Bash Variable Expansion" above):
     ```
     curl -L -o dummy-content/images/<filename>.jpg "<image_url>"
     ```
   - For bulk copying into DDEV, write a shell script:
     ```bash
     # dummy-content/scripts/copy_images.sh
     #!/bin/bash
     for f in /var/www/html/dummy-content/images/*.jpg; do
       filename=$(basename "$f")
       cp "$f" "/var/www/html/web/sites/default/files/$filename"
       echo "Copied: $filename"
     done
     ```
     Then execute: `ddev exec bash /var/www/html/dummy-content/scripts/copy_images.sh`
   - Verify each downloaded file exists and has a reasonable file size (> 1KB).
   - Use descriptive, sanitized filenames that indicate the content type and purpose (e.g., `dummy_<content_type>_<purpose>_01.jpg`).

### Phase 3: Create Media Entities

9. **Script execution approach:** Write PHP scripts to `dummy-content/scripts/` and execute via `ddev drush scr /var/www/html/dummy-content/scripts/<script_name>.php`. **Do NOT delete scripts after execution** — they serve as the persistent record of the content data.

10. For each downloaded image, create a Drupal **Media entity** of type "Image":
    - Create a `file` entity for the downloaded image file.
    - Create a `media` entity of bundle `image` referencing the file entity.
    - Set the media name to a descriptive label that reflects the content type and purpose.
    - Record the media entity ID for use when creating nodes.

    Example pattern:
    ```php
    use Drupal\file\Entity\File;
    use Drupal\media\Entity\Media;

    // Create file entity
    $file = File::create([
      'uri' => 'public://<filename>.jpg',
      'status' => 1,
    ]);
    $file->save();

    // Create media entity
    $media = Media::create([
      'bundle' => 'image',
      'name' => 'Descriptive Name',
      'field_media_image' => [
        'target_id' => $file->id(),
        'alt' => 'Alt text description',
        'title' => 'Image title',
      ],
      'status' => 1,
    ]);
    $media->save();
    ```

11. For content types that require **Document** media (e.g., PDF, Excel fields), create placeholder document media entities:
    - Generate placeholder PDF files using a PHP script (write raw PDF syntax via `file_put_contents`). Save the script to `dummy-content/scripts/create_placeholder_pdfs.php` and execute via `ddev drush scr`.
    - Save the original document to `dummy-content/documents/` first, then copy it into the DDEV public files directory (same approach as images).
    - Create a `media` entity of bundle `document` referencing the file. Use `field_media_document` (verify field name from Phase 0 inspection).

### Phase 4: Create Dummy Nodes

#### Node count target

Create **at least 15 dummy nodes** per content type (or **2** for content types that serve as landing/hub pages) to ensure Views displays, pagination, and faceted filtering look realistic. This count is important for:
- Views with pager (10 per page shows partial second page)
- Taxonomy filtering (enough variety to demonstrate faceted search)
- Grid/list layouts (enough items to fill the layout)

#### Creation order (dependency-aware)

Content types that are referenced by other content types via `entity_reference` fields **MUST be created first**. Inspect the field definitions from Phase 0 to determine the dependency order.

Common dependency chain:
1. **person_profile** — referenced by `article.field_author_profile`
2. All other content types (no inter-dependencies)
3. **article** — last, because it references person_profile nodes

Write separate PHP scripts per content type (e.g., `create_nodes_<content_type>.php`) to `dummy-content/scripts/` and execute via `ddev drush scr`. **Do NOT delete these scripts.**

#### Media reuse strategy

The 2-3 images per content type fetched in Phase 2 are sufficient as a visual base. For the 15+ nodes, **reuse existing media entity IDs in rotation**:
```php
$media_ids = [1, 2, 3]; // IDs from Phase 3
$media_id = $media_ids[$i % count($media_ids)];
```
This avoids excessive image downloads while maintaining variety in Drupal's media library.

#### Generating realistic content

12. Study the Target Site using `WebFetch` to understand the kind of content it publishes. Use this as inspiration to generate realistic dummy data:
    - **Titles**: Should be realistic and varied, inspired by actual content found on the Target Site. Use real product names, executive names, and organizational language where appropriate.
    - **Text fields**: Should contain plausible, multi-sentence or multi-paragraph content appropriate for the field's purpose. Use `full_html` format for text_long fields with proper HTML markup (`<p>`, `<ul>`, `<h3>`, etc.).
    - **Taxonomy reference fields**: Should reference different existing terms across the dummy nodes to demonstrate variety. Look up term IDs dynamically:
      ```php
      $terms = \Drupal::entityTypeManager()->getStorage('taxonomy_term')
        ->loadByProperties(['vid' => 'VOCABULARY_ID', 'name' => 'TERM_NAME']);
      $term = reset($terms);
      $tid = $term->id();
      ```
    - **Link fields**: Should contain plausible URLs inspired by the Target Site's URL patterns.
    - **List/option fields**: Should use different allowed values across the dummy nodes. Use the actual allowed values retrieved during Phase 0 field inspection (not guessed values).
    - **Datetime fields**: Should use varied dates (spread across months/years) to ensure chronological sorting in Views. Use format `Y-m-d\TH:i:s` for datetime or `Y-m-d` for date-only.

13. When creating nodes, ensure:
    - All **required fields** (as specified in the "Implementation Strategy" section of the requirements) are populated.
    - **Entity reference fields** point to actual existing entity IDs of the correct target type and bundle (verified in Phase 0):
      - `media:image` → media entity ID of bundle `image`
      - `media:document` → media entity ID of bundle `document`
      - `taxonomy_term:VOCAB` → term entity ID from the correct vocabulary
      - `node:BUNDLE` → node ID of the correct content type (respect creation order)
    - **Media reference fields** point to actual existing media entity IDs created in Phase 3.
    - All nodes are set to **published** (`'status' => 1`).

### Phase 5: Verification

14. After all operations, verify the results:
    - Count nodes per content type to confirm target numbers:
      ```
      ddev drush sql:query "SELECT type, COUNT(*) as cnt FROM node GROUP BY type ORDER BY type"
      ```
    - List all nodes grouped by content type, showing their titles:
      ```
      ddev drush sql:query "SELECT n.nid, n.type, nfd.title FROM node n JOIN node_field_data nfd ON n.nid = nfd.nid ORDER BY n.type, n.nid"
      ```
    - Confirm that media entities were created:
      ```
      ddev drush sql:query "SELECT mid, bundle, name FROM media_field_data ORDER BY bundle, mid"
      ```
    - Spot-check 2-3 nodes (one per content type) by loading them and verifying key field values are populated:
      ```
      ddev drush php-eval "\$node = \Drupal\node\Entity\Node::load(NODE_ID); echo \$node->toArray()['field_FIELD_NAME'][0]['value'] ?? 'EMPTY';"
      ```

15. Output a summary:
    - Number of media entities created (by type: Image, Document).
    - Number of nodes created per content type (confirm each meets the 15-node target).
    - Any fields that could not be populated and why.

### Phase 6: Documentation

16. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - An image could not be downloaded from the Target Site.
    - A media entity or node could not be created.
    - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., image download failures, media/node creation errors, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 7: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from the failed phase.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from the failed phase.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.

## Notes on Image Handling

- **Copyright awareness:** The images fetched from the Target Site are used solely for development/dummy content purposes in a local environment. This is not intended for production deployment with copyrighted assets.
- **Fallback strategy:** If the Target Site blocks image downloads or images are not accessible, use `WebSearch` to find publicly available images related to the Target Site. As a last resort, generate simple placeholder images using PHP GD library or download from a placeholder service (e.g., `https://placehold.co/800x600?text=Placeholder`).
- **File naming:** Use descriptive, sanitized filenames that indicate the content type and purpose (e.g., `dummy_<content_type>_<purpose>_01.jpg`).
- **Prefer original resolution:** When the Target Site uses a CDN with image transformation (e.g., URLs containing `/dims4/`, `/resize/`, `/crop/`), try to extract the original image URL from the query string or path segments.
