---
name: create-menu
description: Create and configure Drupal menus and menu links by dynamically discovering Views page displays and content structure from the running site.
disable-model-invocation: true
allowed-tools: Bash, Read, Grep, Task
---

# Create Menus and Menu Links

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Overview

This skill creates and configures Drupal menus and their menu link items. It dynamically discovers all Views with page displays from the running Drupal site, reads `REQUIREMENTS.md` to understand the site's content structure and purpose, and builds a logical navigation hierarchy.

The skill creates:
- **Main navigation** menu links for all Views listing pages (and any other key pages).
- **Footer** menu with organizational/legal links if appropriate.
- Properly weighted and ordered menu items reflecting the site's information architecture.

The skill does NOT hardcode content types, Views IDs, paths, or menu link titles. It discovers everything dynamically at runtime.

## Prerequisites

Before running this skill, ensure that:
- Content types have been created (via `create-content-types`).
- Views with page displays have been created (via `create-views`), so that listing pages exist to link to.

If Views page displays do not exist, **stop and inform the user** that the `create-views` skill must be run first.

## Instructions

### Phase 1: Research

1. Use Context7 MCP to look up the latest Drupal 11 / Drush documentation for:
   - The Menu system: available menus (`main`, `footer`, `account`, `admin`, `tools`).
   - How to create custom menus programmatically (`\Drupal\system\Entity\Menu`).
   - How to create menu link content entities programmatically (`\Drupal\menu_link_content\Entity\MenuLinkContent`).
   - Menu link properties: `title`, `link`, `menu_name`, `weight`, `expanded`, `parent`, `enabled`.
   - How to manage parent-child relationships for hierarchical menus.

### Phase 2: Snapshot

2. **Before making any changes**, take a DDEV snapshot as a restore point:
   ```
   ddev snapshot --name pre-create-menu-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

### Phase 3: Discover Views Page Displays and Site Structure

3. **Dynamically discover** all Views that have page displays with paths. This provides the set of listing pages that should be linked from menus.

   ```
   ddev drush php-eval "
   \$views = \Drupal\views\Entity\View::loadMultiple();
   foreach (\$views as \$view) {
     foreach (\$view->get('display') as \$id => \$display) {
       if (\$display['display_plugin'] === 'page') {
         \$path = \$display['display_options']['path'] ?? '';
         \$title = \$display['display_options']['title'] ?? \$view->label();
         if (\$path) {
           echo \$view->id() . ' | ' . \$id . ' | /' . \$path . ' | ' . \$title . PHP_EOL;
         }
       }
     }
   }
   "
   ```

   If no Views page displays are found, **stop and inform the user** that the `create-views` skill must be run first.

4. **Discover all content types** to understand the full site structure:

   ```
   ddev drush php-eval "foreach(\Drupal\node\Entity\NodeType::loadMultiple() as \$t) echo \$t->id().' | '.\$t->label().PHP_EOL;"
   ```

5. **List existing menus** on the site:

   ```
   ddev drush php-eval "
   \$menus = \Drupal\system\Entity\Menu::loadMultiple();
   foreach (\$menus as \$menu) {
     echo \$menu->id() . ' | ' . \$menu->label() . PHP_EOL;
   }
   "
   ```

6. **List existing menu links** to avoid creating duplicates:

   ```
   ddev drush php-eval "
   \$links = \Drupal::entityTypeManager()->getStorage('menu_link_content')->loadMultiple();
   foreach (\$links as \$link) {
     echo \$link->getMenuName() . ' | ' . \$link->getTitle() . ' | ' . \$link->link->uri . ' | weight:' . \$link->getWeight() . PHP_EOL;
   }
   "
   ```

   Also **check for system-provided menu links** (e.g., `standard.front_page` from the Standard install profile) that may conflict with planned custom links:

   ```
   ddev drush php-eval "
   \$tree = \Drupal::menuTree();
   \$params = new \Drupal\Core\Menu\MenuTreeParameters();
   \$params->setMaxDepth(1);
   \$items = \$tree->load('main', \$params);
   \$manipulators = [['callable' => 'menu.default_tree_manipulators:generateIndexAndSort']];
   \$items = \$tree->transform(\$items, \$manipulators);
   foreach (\$items as \$element) {
     \$link = \$element->link;
     echo \$link->getTitle() . ' | ' . \$link->getUrlObject()->toString() . ' | plugin: ' . \$link->getPluginId() . PHP_EOL;
   }
   "
   ```

   If a system link like `standard.front_page` (Home → `/`) is found, plan to disable it in Phase 5 to prevent duplicate entries when a custom Home link is created.

7. Read `REQUIREMENTS.md` to understand the site purpose, content types, and their intended audience/hierarchy. Use this context to determine:
   - **Menu placement**: Which pages belong in main navigation vs. footer vs. other menus.
   - **Menu link titles**: Use short, user-friendly labels (e.g., "Products" instead of "Medicinal Product Listing").
   - **Ordering/weight**: Place the most important or frequently accessed pages first (lower weight).
   - **Hierarchy**: Group related items under parent menu links if the site has a logical sub-navigation (e.g., "About" → "Leadership", "Board of Directors").
   - **Home link**: Include a "Home" link pointing to `<front>` as the first item in main navigation if one does not already exist.

### Phase 4: Plan Menu Structure

8. Based on the discovered Views pages, content types, and requirements, draft the complete menu structure before creating anything. The structure should include:
   - Menu name (e.g., `main`, `footer`)
   - Link title
   - Path (internal URI format: `internal:/path`)
   - Weight (ordering)
   - Parent link (for hierarchical items)

   **Guidelines for menu structure:**
   - **Main navigation** (`main`): Include the primary listing pages visitors would use. Keep it concise (typically 5-8 top-level items). Group related items under parent links if there are many content types.
   - **Footer menu** (`footer`): Include supplementary or legal links. If the requirements mention any pages suitable for the footer (e.g., Careers, Investor Relations, Privacy Policy), place them here.
   - For the `<front>` (Home) link, use `internal:/` as the URI.
   - For Views listing pages, use `internal:/PAGE_PATH` as the URI (e.g., `internal:/news`, `internal:/products`).

### Phase 5: Create Menu Links

9. **Script execution approach:** Write a PHP script to create all menu links programmatically, then execute it via `ddev drush scr`.
   - Write the script to the **project root** (e.g., `create_menu.php`), NOT to `/tmp` or any host-only path, because the DDEV container can only access files inside the project directory.
   - Execute via `ddev drush scr /var/www/html/create_menu.php` (using the container-side path).
   - Delete the script after successful execution.

10. The PHP script must:
    - Create any custom menus that don't already exist (if needed beyond the standard `main` and `footer`).
    - Create `MenuLinkContent` entities for each planned menu item.
    - **Check if each menu link already exists** before creating it (check by menu name + URI to avoid duplicates).
    - Handle parent-child relationships by creating parent links first, then referencing them in child links.
    - **Disable the system-default Home link** if a custom Home link (`internal:/`) is being created for the `main` menu. The Drupal Standard install profile ships a `standard.front_page` system menu link that points to `/`, causing a duplicate "Home" entry in the menu tree. The script must disable it after creating the custom Home link.

    **Example for creating a custom menu:**
    ```php
    use Drupal\system\Entity\Menu;

    $menu_id = 'MENU_MACHINE_NAME';
    $menu = Menu::load($menu_id);
    if (!$menu) {
      $menu = Menu::create([
        'id' => $menu_id,
        'label' => 'Menu Human Label',
        'description' => 'Description of the menu.',
      ]);
      $menu->save();
      echo "Created menu: $menu_id\n";
    }
    else {
      echo "Menu '$menu_id' already exists. Skipping.\n";
    }
    ```

    **Example for creating a menu link:**
    ```php
    use Drupal\menu_link_content\Entity\MenuLinkContent;

    // Check for existing link with same menu and URI.
    $existing = \Drupal::entityTypeManager()
      ->getStorage('menu_link_content')
      ->loadByProperties([
        'menu_name' => 'main',
        'link__uri' => 'internal:/PAGE_PATH',
      ]);

    if (empty($existing)) {
      $link = MenuLinkContent::create([
        'title' => 'Link Title',
        'link' => ['uri' => 'internal:/PAGE_PATH'],
        'menu_name' => 'main',
        'weight' => 0,
        'expanded' => TRUE,  // Set TRUE for parent items with children
        'enabled' => TRUE,
      ]);
      $link->save();
      echo "Created menu link: 'Link Title' -> /PAGE_PATH\n";
    }
    else {
      echo "Menu link to /PAGE_PATH already exists in 'main'. Skipping.\n";
    }
    ```

    **Example for disabling the system-default Home link:**
    ```php
    // Disable the standard.front_page system link to prevent duplicate Home entries.
    // This is necessary on sites installed with the Standard profile.
    $menu_link_manager = \Drupal::service('plugin.manager.menu.link');
    $menu_link_manager->updateDefinition('standard.front_page', ['enabled' => FALSE]);
    echo "Disabled system default Home link (standard.front_page).\n";
    ```

    **Example for creating a child menu link:**
    ```php
    // First, find the parent link's plugin ID.
    $parent_links = \Drupal::entityTypeManager()
      ->getStorage('menu_link_content')
      ->loadByProperties([
        'menu_name' => 'main',
        'link__uri' => 'internal:/PARENT_PATH',
      ]);
    $parent_link = reset($parent_links);
    $parent_plugin_id = $parent_link ? 'menu_link_content:' . $parent_link->uuid() : '';

    $child = MenuLinkContent::create([
      'title' => 'Child Link Title',
      'link' => ['uri' => 'internal:/CHILD_PATH'],
      'menu_name' => 'main',
      'parent' => $parent_plugin_id,
      'weight' => 0,
      'enabled' => TRUE,
    ]);
    $child->save();
    ```

### Phase 6: Verification

11. Verify that all menu links were created successfully:

    ```
    ddev drush php-eval "
    \$menus = ['main', 'footer'];
    foreach (\$menus as \$menu_name) {
      echo \"=== \$menu_name ===\" . PHP_EOL;
      \$links = \Drupal::entityTypeManager()->getStorage('menu_link_content')->loadByProperties(['menu_name' => \$menu_name]);
      foreach (\$links as \$link) {
        \$parent = \$link->getParentId() ? ' (child of: ' . \$link->getParentId() . ')' : '';
        echo '  [w:' . \$link->getWeight() . '] ' . \$link->getTitle() . ' -> ' . \$link->link->uri . \$parent . PHP_EOL;
      }
    }
    "
    ```

12. Verify menu rendering by checking the menu tree structure:

    ```
    ddev drush php-eval "
    \$menu_tree = \Drupal::menuTree();
    \$parameters = new \Drupal\Core\Menu\MenuTreeParameters();
    \$parameters->setMaxDepth(3);
    \$tree = \$menu_tree->load('main', \$parameters);
    \$manipulators = [
      ['callable' => 'menu.default_tree_manipulators:generateIndexAndSort'],
    ];
    \$tree = \$menu_tree->transform(\$tree, \$manipulators);
    foreach (\$tree as \$element) {
      \$link = \$element->link;
      echo \$link->getTitle() . ' -> ' . \$link->getUrlObject()->toString() . PHP_EOL;
      if (\$element->subtree) {
        foreach (\$element->subtree as \$child) {
          echo '  └─ ' . \$child->link->getTitle() . ' -> ' . \$child->link->getUrlObject()->toString() . PHP_EOL;
        }
      }
    }
    "
    ```

13. Verify that the menu link paths resolve correctly (no 404 errors):

    ```
    ddev drush php-eval "
    \$links = \Drupal::entityTypeManager()->getStorage('menu_link_content')->loadByProperties(['menu_name' => 'main']);
    foreach (\$links as \$link) {
      \$uri = \$link->link->uri;
      \$path = str_replace('internal:', '', \$uri);
      if (\$path && \$path !== '/') {
        echo \$link->getTitle() . ' (' . \$path . '): ';
        try {
          \$url = \Drupal\Core\Url::fromUri(\$uri);
          \$routed = \$url->isRouted();
          echo \$routed ? 'OK (routed)' : 'OK (external/unrouted)';
        } catch (\Exception \$e) {
          echo 'ERROR: ' . \$e->getMessage();
        }
        echo PHP_EOL;
      }
    }
    "
    ```

14. Clear all caches after creating menu links:
    ```
    ddev drush cr
    ```

15. Output a summary:
    - List of menus created or used.
    - List of menu links created (menu, title, path, weight, parent).
    - Which menu links already existed and were skipped.
    - Any errors encountered during creation.

### Phase 7: Cleanup and Documentation

16. Delete the PHP script from the project root after successful execution.

17. If any of the following situations occur, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - A menu link was created but points to a non-existent path.
    - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., menu link creation errors, site becomes unstable):

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
