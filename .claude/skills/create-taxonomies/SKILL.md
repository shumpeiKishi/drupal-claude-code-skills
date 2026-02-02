---
name: create-taxonomies
description: Create all taxonomy vocabularies and terms defined in REQUIREMENTS.md using Drush commands via DDEV.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Task
---

# Create Taxonomy Vocabularies and Terms

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Instructions

1. Parse the "2. Taxonomy Vocabularies and Terms" section from the requirements above. Identify every vocabulary (machine name), its description, and its terms (including term descriptions if available).

2. Use Context7 MCP to look up the latest Drupal 11 / Drush documentation for taxonomy vocabulary and term creation. Confirm the correct Drush commands and options.

3. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-create-taxonomies-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

4. For each vocabulary, run via `ddev drush`:
   - Check if the vocabulary already exists. If not, create it with its **description** set.
   - For each term under the vocabulary, check if it already exists. If not, create it with its **description** set.
   - **Description rules:** Use the description provided in `REQUIREMENTS.md`. If no explicit description is given, infer an appropriate description from the vocabulary name, term name, and surrounding context (e.g., the section heading or explanatory text in the requirements).

5. After all operations, verify the results:
   - List all vocabularies to confirm creation, including their descriptions.
   - List terms per vocabulary to confirm they are correct, including their descriptions.

6. Output a summary: which vocabularies/terms were created and which already existed.

7. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
   - A command fails or returns an unexpected error.
   - A command succeeds but the result does not match the expected behavior.
   - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., vocabulary/term creation errors, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 3: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 4.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 4.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.
