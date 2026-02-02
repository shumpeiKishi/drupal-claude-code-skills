---
name: configure-pathauto
description: Install and configure the Pathauto module to auto-generate URL aliases for all content types and taxonomy vocabularies in the current Drupal site.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Task
---

# Configure Pathauto URL Aliases

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Overview

This skill installs the Pathauto contributed module and configures URL alias patterns for every content type and taxonomy vocabulary present in the site. Pathauto automatically generates clean, human-readable URL aliases based on token patterns whenever content is created or updated.

## Instructions

### Phase 1: Research

1. Use Context7 MCP to look up the latest Drupal 11 documentation for:
   - The Pathauto module: installation, configuration, and API for creating patterns programmatically.
   - The Token module (Pathauto dependency): available token patterns for nodes and taxonomy terms.
   - How to create `pathauto.pattern.*` configuration entities programmatically via PHP (`\Drupal\pathauto\Entity\PathautoPattern`).

### Phase 2: Snapshot

2. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-configure-pathauto-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 3: Install Modules

3. Install the Pathauto module and its dependencies via Composer:
   ```
   ddev composer require drupal/pathauto
   ```
   This will also pull in the `token` module as a dependency.

4. Enable the required modules:
   ```
   ddev drush en pathauto token -y
   ```

5. Verify the modules are enabled:
   Note: `--filter` does not accept comma-separated values in Drush 13. Pipe through `grep` instead:
   ```
   ddev drush pm:list --status=enabled --type=module | grep -E "pathauto|token"
   ```

### Phase 4: Discover Content Types and Taxonomy Vocabularies

6. **Dynamically discover** all content types and taxonomy vocabularies currently installed on the site. Do NOT hardcode specific machine names.

   ```
   ddev drush entity:list --filter=node_type
   ddev drush entity:list --filter=taxonomy_vocabulary
   ```

   Or use PHP evaluation:
   ```
   ddev drush php-eval "foreach(\Drupal\node\Entity\NodeType::loadMultiple() as \$t) echo \$t->id().' | '.\$t->label().PHP_EOL;"
   ddev drush php-eval "foreach(\Drupal\taxonomy\Entity\Vocabulary::loadMultiple() as \$v) echo \$v->id().' | '.\$v->label().PHP_EOL;"
   ```

7. Also read `REQUIREMENTS.md` to understand the purpose of each content type and vocabulary. Use this context to determine appropriate URL prefix patterns. Apply these guidelines:
   - Choose a short, meaningful English prefix that reflects the content type's purpose (e.g., a news/blog type might use `/news/`, a product type might use `/products/`).
   - For generic or flexible page types (e.g., landing pages), use `/[node:title]` without a prefix.
   - For taxonomy terms, use a URL-friendly version of the vocabulary name as the prefix (e.g., vocabulary `content_tags` → `/tags/[term:name]`).
   - Keep all prefixes lowercase and hyphenated.

### Phase 5: Configure URL Alias Patterns

8. **Script execution approach:** Write a PHP script to create all pathauto patterns programmatically, then execute it via `ddev drush scr`.
   - Write the script to the **project root** (e.g., `configure_pathauto.php`), NOT to `/tmp` or any host-only path, because the DDEV container can only access files inside the project directory.
   - Execute via `ddev drush scr /var/www/html/configure_pathauto.php` (using the container-side path).
   - Delete the script after successful execution.

9. The PHP script must create `PathautoPattern` entities for each discovered content type and taxonomy vocabulary. Check if each pattern already exists before creating it.

   **Example for a content type pattern:**
   ```php
   use Drupal\pathauto\Entity\PathautoPattern;

   $pattern_id = 'content_MACHINE_NAME';
   $pattern = PathautoPattern::load($pattern_id);
   if (!$pattern) {
     $pattern = PathautoPattern::create([
       'id' => $pattern_id,
       'label' => 'HUMAN_LABEL',
       'type' => 'canonical_entities:node',
       'pattern' => '/PREFIX/[node:title]',
       'weight' => 0,
     ]);
     $pattern->addSelectionCondition([
       'id' => 'entity_bundle:node',
       'bundles' => ['MACHINE_NAME'],
       'negate' => FALSE,
       'context_mapping' => ['node' => 'node'],
     ]);
     $pattern->save();
   }
   ```

   **Example for a taxonomy term pattern:**
   ```php
   $pattern_id = 'taxonomy_MACHINE_NAME';
   $pattern = PathautoPattern::load($pattern_id);
   if (!$pattern) {
     $pattern = PathautoPattern::create([
       'id' => $pattern_id,
       'label' => 'HUMAN_LABEL',
       'type' => 'canonical_entities:taxonomy_term',
       'pattern' => '/PREFIX/[term:name]',
       'weight' => 0,
     ]);
     $pattern->addSelectionCondition([
       'id' => 'entity_bundle:taxonomy_term',
       'bundles' => ['MACHINE_NAME'],
       'negate' => FALSE,
       'context_mapping' => ['taxonomy_term' => 'taxonomy_term'],
     ]);
     $pattern->save();
   }
   ```

   **Important:** Research the exact API via Context7 to confirm field names and methods. The examples above are references; the actual API may differ slightly depending on the Pathauto version.

### Phase 6: Generate Aliases for Existing Content

10. After creating all patterns, generate (bulk update) URL aliases for all existing content. Use the `all` option to force (re)generation of aliases for every entity, including ones that already have aliases. The `update` option only targets entities without an alias and will report "No new URL aliases to generate" if all entities already have one (even if the alias was not created by Pathauto):
    ```
    ddev drush pathauto:aliases-generate all
    ```
    Verify that the output reports the number of generated aliases. If existing content is present, this number should be greater than 0.

### Phase 7: Verification

11. Verify that all pathauto patterns were created successfully:
    Note: `drush config:list` does not exist in Drush 13. Use `php-eval` instead:
    ```
    ddev drush php-eval "\$names = \Drupal::configFactory()->listAll('pathauto.pattern'); foreach(\$names as \$name) echo \$name.PHP_EOL;"
    ```

12. For each pattern, verify its configuration:
    ```
    ddev drush config:get pathauto.pattern.<pattern_id>
    ```

13. Verify that URL aliases are being generated correctly. If there is existing content, check:
    Note: The `path_alias` table uses `path` (not `source`) and `alias` columns.
    ```
    ddev drush sql:query "SELECT path, alias FROM path_alias LIMIT 20;"
    ```

14. Output a summary: which patterns were created, which already existed, and whether bulk alias generation succeeded.

### Phase 8: Cleanup and Documentation

15. Delete the PHP script from the project root after successful execution.

16. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., module installation errors, pattern creation errors, site becomes unstable):

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
