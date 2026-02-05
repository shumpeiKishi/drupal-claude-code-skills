---
command: create-footer-component
description: Create a Single Directory Component (SDC) for the site footer with copyright, site name, and dynamic footer menu
triggers: []
enabled: true
temperature: 0.5
max_turns: 10
model: sonnet
provider: anthropic
---

# Task

Create a Single Directory Component (SDC) for the site footer that integrates site branding (site name, copyright) with dynamic, admin-editable footer menus.

# Implementation Strategy

## Architecture
- Footer SDC with Menu as Prop
- `.theme` file prepares data (site name, current year, footer menu tree)
- SDC receives all data as props (no slots)
- Menu remains fully dynamic (admin UI editable)
- Menu tree API provides render array for SDC

## Key Design Decision
Pass footer menu as a **prop** (not slot) to the SDC using Menu Tree API. This gives full control over menu markup within the SDC while maintaining admin editability.

# Prerequisites

Before running this skill, ensure:
1. Custom theme exists and is enabled
2. SDC is configured (`components/` directory exists) - run `/setup-sdc-tailwind` if needed

# Steps

## Phase 1: Setup and Discovery

1. Take DDEV snapshot:
```bash
ddev snapshot --name pre-create-footer-component-$(date +%Y%m%d%H%M%S)
```

2. Read `REQUIREMENTS.md` to extract Target Site URL

3. Derive theme name from URL:
   - Extract domain from Target Site URL (e.g., `www.jnj.com`)
   - Remove `www.` prefix if present
   - Replace `.` with `_`
   - Add `_custom_theme` suffix
   - Example: `www.jnj.com` → `jnj_custom_theme`

4. Verify theme exists and is enabled:
```bash
ddev drush pm:list --type=theme --status=enabled --format=json | grep -i <theme_name>
```

5. Verify SDC setup:
```bash
ls -la web/themes/custom/<theme_name>/components/
```
If directory doesn't exist, exit with error:
```
ERROR: SDC not configured. Please run /setup-sdc-tailwind skill first.
```

## Phase 2: Verify Footer Menu

**Note:** The footer menu (`system.menu.footer`) typically already exists in Drupal core as a default menu. This phase verifies its existence.

1. Verify footer menu exists:
```bash
ddev drush config:get system.menu.footer
```

2. Expected output should show:
   - `id: footer`
   - `label: Footer`
   - `status: true`

3. If the footer menu doesn't exist (rare case), create it manually:
```bash
ddev drush php:eval "
\$menu = \Drupal\system\Entity\Menu::create([
  'id' => 'footer',
  'label' => 'Footer',
  'description' => 'Footer navigation links',
]);
\$menu->save();
"
```

**Common Scenario:** In most Drupal installations, the footer menu is already present and locked (system menu). If you see `locked: true` in the output, this is normal and expected.

## Phase 3: Create SDC Component

1. Create component directory:
```bash
mkdir -p web/themes/custom/<theme_name>/components/site-footer/
```

2. Create `site-footer.component.yml`:
```yaml
$schema: https://git.drupalcode.org/project/drupal/-/raw/HEAD/core/modules/sdc/src/metadata.schema.json
name: Site Footer
status: stable
props:
  type: object
  properties:
    site_name:
      type: string
      title: Site Name
      description: The name of the site
    current_year:
      type: number
      title: Current Year
      description: The current year for copyright notice
    footer_menu:
      title: Footer Menu
      description: The footer navigation menu render array (built by Menu Tree API)
```

3. Create `site-footer.twig`:
```twig
{#
/**
 * @file
 * Site Footer Component
 *
 * Displays copyright notice and footer navigation menu.
 */
#}
<div class="border-t border-gray-200 bg-gray-50">
  <div class="max-w-7xl mx-auto py-8 px-6">
    <div class="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0">
      <div class="text-sm text-gray-600">
        <p>&copy; {{ current_year }} {{ site_name }}. All rights reserved.</p>
      </div>
      {% if footer_menu %}
        <nav class="footer-menu">
          {{ footer_menu }}
        </nav>
      {% endif %}
    </div>
  </div>
</div>
```

## Phase 4: Add Preprocess Hook

1. Read the theme file:
```bash
cat web/themes/custom/<theme_name>/<theme_name>.theme
```

2. Add footer-specific code to existing `hook_preprocess_page()` (or create it if it doesn't exist):
```php
/**
 * Implements hook_preprocess_page().
 */
function <theme_name>_preprocess_page(&$variables) {
  // Get site name from configuration
  $site_config = \Drupal::config('system.site');
  $variables['site_name'] = $site_config->get('name') ?: 'Home';

  // Get current year for copyright
  $variables['current_year'] = date('Y');

  // Get footer menu items
  $menu_tree = \Drupal::menuTree();
  $menu_name = 'footer';
  $parameters = $menu_tree->getCurrentRouteMenuTreeParameters($menu_name);
  $parameters->setMaxDepth(1);
  $tree = $menu_tree->load($menu_name, $parameters);
  $manipulators = [
    ['callable' => 'menu.default_tree_manipulators:checkAccess'],
    ['callable' => 'menu.default_tree_manipulators:generateIndexAndSort'],
  ];
  $tree = $menu_tree->transform($tree, $manipulators);
  $menu_build = $menu_tree->build($tree);
  $variables['footer_menu'] = $menu_build;

  // Add cache metadata
  $variables['#cache']['contexts'][] = 'theme';
  $variables['#cache']['contexts'][] = 'route.menu_active_trails:footer';
  $variables['#cache']['tags'] = array_merge(
    $variables['#cache']['tags'] ?? [],
    $site_config->getCacheTags(),
    ['config:system.menu.footer']
  );

  // Add max-age for year-based cache invalidation
  $variables['#cache']['max-age'] = \Drupal\Core\Cache\Cache::mergeMaxAges(
    $variables['#cache']['max-age'] ?? \Drupal\Core\Cache\Cache::PERMANENT,
    strtotime('tomorrow') - time()
  );
}
```

**Important Notes:**
- If `hook_preprocess_page()` already exists (e.g., from `/create-header-component`), merge the footer-specific code into the existing function
- Don't duplicate the function declaration
- Don't duplicate site name, site config, or cache contexts that are already defined
- Merge cache tags and contexts properly

**Example of Merging with Existing Hook:**

If the function already exists with header code:
```php
function <theme_name>_preprocess_page(&$variables) {
  // Existing header code
  $site_config = \Drupal::config('system.site');
  $variables['site_name'] = $site_config->get('name') ?: 'Home';
  $variables['site_logo'] = theme_get_setting('logo.url');

  // Existing main menu code
  $menu_tree = \Drupal::menuTree();
  $menu_name = 'main';
  // ... main menu code ...
  $variables['main_menu'] = $menu_build;

  // Existing cache metadata
  $variables['#cache']['contexts'][] = 'theme';
  $variables['#cache']['contexts'][] = 'route.menu_active_trails:main';
  // ...
}
```

You should ADD the following footer-specific code (not duplicate):
1. Add `$variables['current_year'] = date('Y');` after site_name
2. Add footer menu code after main menu code (reuse `$menu_tree` variable)
3. Add `'route.menu_active_trails:footer'` to existing cache contexts array
4. Add `'config:system.menu.footer'` to existing cache tags array
5. Add max-age cache setting at the end

**Key Point:** Use the same `$menu_tree` variable and `$manipulators` array that already exist. Don't redeclare `$site_config` - it's already defined.

## Phase 5: Update Page Template

1. Read the page template:
```bash
cat web/themes/custom/<theme_name>/templates/layout/page.html.twig
```

2. Add footer section before closing `</body>` or at the end of the main layout:
```twig
  <footer class="site-footer">
    {% include '<theme_name>:site-footer' with {
      site_name: site_name,
      current_year: current_year,
      footer_menu: footer_menu,
    } only %}
  </footer>
```

**Important:**
- Replace `<theme_name>` with the actual theme name (e.g., `jnj_custom_theme`)
- Use `{% include %}` to pass all data as props
- Place footer after main content area and before closing wrapper

## Phase 6: Style Footer Menu

1. Verify navigation templates directory exists:
```bash
ls -la web/themes/custom/<theme_name>/templates/navigation/
```

If it doesn't exist:
```bash
mkdir -p web/themes/custom/<theme_name>/templates/navigation/
```

2. Create `menu--footer.html.twig` with Tailwind styling:
```twig
{#
/**
 * @file
 * Theme override to display the footer menu with Tailwind styling.
 *
 * Available variables:
 * - menu_name: The machine name of the menu.
 * - items: A nested list of menu items. Each menu item contains:
 *   - attributes: HTML attributes for the menu item.
 *   - below: The menu item child items.
 *   - title: The menu link title.
 *   - url: The menu link URL, instance of \Drupal\Core\Url
 *   - localized_options: Menu link localized options.
 *   - is_expanded: TRUE if the link has visible children within the current
 *     menu tree.
 *   - is_collapsed: TRUE if the link has children within the current menu tree
 *     that are not currently visible.
 *   - in_active_trail: TRUE if the link is in the active trail.
 */
#}
{% import _self as menus %}

{{ menus.menu_links(items, attributes, 0) }}

{% macro menu_links(items, attributes, menu_level) %}
  {% import _self as menus %}
  {% if items %}
    <ul{{ attributes.addClass('flex', 'flex-wrap', 'gap-x-6', 'gap-y-2', 'text-sm') }}>
    {% for item in items %}
      {% set item_classes = [
        'text-gray-600',
        'hover:text-gray-900',
        'transition-colors',
        'duration-200',
        item.in_active_trail ? 'font-semibold text-gray-900',
      ] %}
      <li{{ item.attributes }}>
        <a href="{{ item.url }}" class="{{ item_classes|join(' ') }}">{{ item.title }}</a>
      </li>
    {% endfor %}
    </ul>
  {% endif %}
{% endmacro %}
```

**Key Features:**
- **Horizontal layout**: `flex flex-wrap gap-x-6 gap-y-2`
- **Responsive**: Wraps on smaller screens
- **Small text**: `text-sm` for footer
- **Hover effects**: Color transition on hover
- **Active trail**: Bold text for current page
- **Single level**: No nested menus (maxDepth=1 in preprocess)

3. Rebuild Tailwind CSS to include new utility classes:
```bash
ddev exec "cd web/themes/custom/<theme_name> && npm run build"
```

4. Clear caches:
```bash
ddev drush cache:rebuild
```

## Phase 7: Verification

1. Clear all caches:
```bash
ddev drush cache:rebuild
```

2. Launch site:
```bash
ddev launch
```

3. Verify:
   - Site name displays in copyright
   - Current year displays correctly
   - Footer menu renders (may be empty initially)
   - Footer styling is applied

4. Test dynamic updates:
   - Check site name: `ddev drush config:get system.site name`
   - Check footer menu label: `ddev drush config:get system.menu.footer label`
   - Visit admin: `/admin/config/system/site-information`
   - Visit menu management: `/admin/structure/menu/manage/footer`
   - Add menu items to test menu rendering

**Note:** The `drush menu:list` command does not exist in Drush 13. Use `ddev drush config:get system.menu.footer` to verify the footer menu configuration instead.

# Error Handling

## Theme Not Found
If theme verification fails during Phase 1, Step 4:
```
ERROR: Theme '<theme_name>' not found or not enabled.
Please run /create-starterkit-theme skill first.
```

## SDC Directory Missing
If components directory doesn't exist during Phase 1, Step 5:
```
ERROR: SDC not configured. Please run /setup-sdc-tailwind skill first.
```

## Menu Already Exists
**This is the expected behavior.** The footer menu typically already exists in Drupal core installations. In Phase 2:
- If `ddev drush config:get system.menu.footer` shows the menu configuration, proceed to Phase 3
- If you see `locked: true`, this is normal (system menu)
- Only log to `RETROSPECTIVE.md` if the menu genuinely doesn't exist and manual creation also fails

# Retry Policy

If any step fails:
1. Log the error to `RETROSPECTIVE.md`
2. Attempt to fix the issue automatically (if possible)
3. Retry up to 3 times
4. If all retries fail, exit with clear error message

# Success Criteria

- ✅ Footer menu verified (typically already exists in Drupal core)
- ✅ SDC component created with valid YAML schema
- ✅ Preprocess hook added/updated in theme file (merged if header component exists)
- ✅ Page template updated to use footer SDC with props
- ✅ Footer menu template created with Tailwind styling
- ✅ Tailwind CSS rebuilt to include new utility classes
- ✅ Caches cleared successfully
- ✅ Site displays footer with copyright and menu
- ✅ Footer menu remains editable via Drupal admin UI

# Notes

**Drupal Core Footer Menu:** The footer menu (`system.menu.footer`) is a default menu provided by Drupal core. It typically already exists in fresh Drupal installations and is marked as `locked: true`, which means it's a system menu that cannot be deleted. This is normal and expected behavior.

**Menu Handling:** Footer menu is fetched using Menu Tree API in the preprocess hook and passed as a render array prop to the SDC. Menu remains fully editable via Drupal admin UI (`/admin/structure/menu/manage/footer`). The menu structure and items can be modified by admins, even though the menu entity itself is locked.

**Copyright Year:** Current year is calculated dynamically using PHP's `date('Y')` function and cached until tomorrow to ensure automatic year updates.

**Footer Menu vs Main Menu:** Footer menus typically have fewer items and no nested levels. The template uses `maxDepth=1` to keep the footer menu flat and simple.

**Styling Flexibility:** Tailwind classes in SDC can be customized. Consider utility classes for:
- Background color: `bg-gray-50`, `bg-gray-100`, `bg-white`
- Border: `border-t border-gray-200`, `border-t-2`
- Text color: `text-gray-600`, `text-gray-500`
- Padding: `py-8 px-6`, `py-6 px-4`

**SEO & Accessibility:**
- Footer wrapped in semantic `<footer>` tag
- Copyright text in paragraph tag
- Menu wrapped in `<nav>` with proper ARIA attributes
- Links have proper hover states and focus indicators

**Preprocess Hook Merging:**
If header component was already created, the `hook_preprocess_page()` function will already exist. In that case:
1. Read the existing function first using the Read tool
2. Add only the footer-specific variables (current_year, footer_menu)
3. Reuse existing variables: `$menu_tree`, `$site_config`, `$manipulators`
4. Add footer-specific cache contexts and tags to existing arrays (don't duplicate 'theme' context)
5. Add max-age cache setting at the end

**Concrete Example:**
After existing main menu code:
```php
$variables['main_menu'] = $menu_build;

// ADD FOOTER CODE HERE:
$variables['current_year'] = date('Y');

$footer_menu_name = 'footer';
$footer_parameters = $menu_tree->getCurrentRouteMenuTreeParameters($footer_menu_name);
$footer_parameters->setMaxDepth(1);
$footer_tree = $menu_tree->load($footer_menu_name, $footer_parameters);
$footer_tree = $menu_tree->transform($footer_tree, $manipulators); // Reuse existing $manipulators
$footer_menu_build = $menu_tree->build($footer_tree);
$variables['footer_menu'] = $footer_menu_build;
```

Then update existing cache arrays:
```php
// Add to existing contexts (don't duplicate 'theme')
$variables['#cache']['contexts'][] = 'route.menu_active_trails:footer';

// Add to existing tags
$variables['#cache']['tags'] = array_merge(
  $variables['#cache']['tags'] ?? [],
  $site_config->getCacheTags(),
  ['config:system.menu.main'],
  ['config:system.menu.footer'] // Add this line
);

// Add max-age at the end
$variables['#cache']['max-age'] = \Drupal\Core\Cache\Cache::mergeMaxAges(
  $variables['#cache']['max-age'] ?? \Drupal\Core\Cache\Cache::PERMANENT,
  strtotime('tomorrow') - time()
);
```

# Post-Execution

After successful execution:
1. Restore DDEV snapshot if needed: `ddev snapshot restore <snapshot_name>`
2. Update `RETROSPECTIVE.md` with any issues encountered
3. Verify all files are committed to git
4. Add menu items to footer menu via admin UI for complete testing
