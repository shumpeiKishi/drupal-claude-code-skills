---
command: create-header-component
description: Create a Single Directory Component (SDC) for the site header with logo, site name, and dynamic menu
triggers: []
enabled: true
temperature: 0.5
max_turns: 10
model: sonnet
provider: anthropic
---

# Task

Create a Single Directory Component (SDC) for the site header that integrates site branding (logo, site name) with dynamic, admin-editable menus.

# Implementation Strategy

## Architecture
- Header SDC with Menu as Prop
- `.theme` file prepares data (site name, logo URL, menu tree)
- SDC receives all data as props (no slots)
- Menu remains fully dynamic (admin UI editable)
- Menu tree API provides render array for SDC

## Key Design Decision
Pass menu as a **prop** (not slot) to the SDC using Menu Tree API. This gives full control over menu markup within the SDC while maintaining admin editability.

# Prerequisites

Before running this skill, ensure:
1. Custom theme exists and is enabled
2. SDC is configured (`components/` directory exists) - run `/setup-sdc-tailwind` if needed

# Steps

## Phase 1: Setup and Discovery

1. Take DDEV snapshot:
```bash
ddev snapshot --name pre-create-header-component-$(date +%Y%m%d%H%M%S)
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

## Phase 2: Create SDC Component

1. Create component directory:
```bash
mkdir -p web/themes/custom/<theme_name>/components/site-header/
```

2. Create `site-header.component.yml`:
```yaml
$schema: https://git.drupalcode.org/project/drupal/-/raw/HEAD/core/modules/sdc/src/metadata.schema.json
name: Site Header
status: stable
props:
  type: object
  properties:
    logo_url:
      type: string
      title: Logo URL
      description: Path to the site logo image
    site_name:
      type: string
      title: Site Name
      description: The name of the site
    menu:
      title: Main Menu
      description: The main navigation menu render array (built by Menu Tree API)
```

3. Create `site-header.twig`:
```twig
{#
/**
 * @file
 * Site Header Component
 *
 * Displays site logo, name, and navigation menu.
 */
#}
<div class="flex items-center justify-between py-4 px-6 shadow-sm bg-white">
  <a href="/" class="flex items-center space-x-3">
    {% if logo_url %}
      <img src="{{ logo_url }}" alt="{{ site_name }}" class="h-10 w-auto">
    {% endif %}
    <span class="text-xl font-bold tracking-tight text-gray-900">{{ site_name }}</span>
  </a>
  <nav>
    {{ menu }}
  </nav>
</div>
```

## Phase 3: Add Preprocess Hook

1. Read the theme file:
```bash
cat web/themes/custom/<theme_name>/<theme_name>.theme
```

2. Add `hook_preprocess_page()` after existing hooks:
```php
/**
 * Implements hook_preprocess_page().
 */
function <theme_name>_preprocess_page(&$variables) {
  // Get site name from configuration
  $site_config = \Drupal::config('system.site');
  $variables['site_name'] = $site_config->get('name') ?: 'Home';

  // Get logo URL from theme settings
  $variables['site_logo'] = theme_get_setting('logo.url');

  // Get main menu items
  $menu_tree = \Drupal::menuTree();
  $menu_name = 'main';
  $parameters = $menu_tree->getCurrentRouteMenuTreeParameters($menu_name);
  $parameters->setMaxDepth(2);
  $tree = $menu_tree->load($menu_name, $parameters);
  $manipulators = [
    ['callable' => 'menu.default_tree_manipulators:checkAccess'],
    ['callable' => 'menu.default_tree_manipulators:generateIndexAndSort'],
  ];
  $tree = $menu_tree->transform($tree, $manipulators);
  $menu_build = $menu_tree->build($tree);
  $variables['main_menu'] = $menu_build;

  // Add cache metadata
  $variables['#cache']['contexts'][] = 'theme';
  $variables['#cache']['contexts'][] = 'route.menu_active_trails:main';
  $variables['#cache']['tags'] = array_merge(
    $variables['#cache']['tags'] ?? [],
    $site_config->getCacheTags(),
    ['config:system.menu.main']
  );
}
```

## Phase 4: Update Page Template

1. Read the page template:
```bash
cat web/themes/custom/<theme_name>/templates/layout/page.html.twig
```

2. Replace the header section with:
```twig
  <header class="site-header">
    {% include '<theme_name>:site-header' with {
      logo_url: site_logo,
      site_name: site_name,
      menu: main_menu,
    } only %}
  </header>
```

**Important:**
- Replace `<theme_name>` with the actual theme name (e.g., `jnj_custom_theme`)
- Use `{% include %}` to pass all data as props. Since menu is a prop (not slot), we don't need `{% embed %}`.

## Phase 5: Style Menu with Dropdown

1. Create navigation templates directory:
```bash
mkdir -p web/themes/custom/<theme_name>/templates/navigation
```

2. Create `menu--main.html.twig` with Tailwind styling and dropdown functionality:
```twig
{#
/**
 * @file
 * Theme override to display the main menu with Tailwind styling.
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
    {% if menu_level == 0 %}
      <ul{{ attributes.addClass('flex', 'space-x-6', 'items-center') }}>
    {% else %}
      <ul class="hidden group-hover:block absolute left-0 top-full pt-2 z-50">
        <div class="py-2 w-48 bg-white rounded-md shadow-lg border border-gray-200">
    {% endif %}
    {% for item in items %}
      {% set item_classes = [
        menu_level == 0 ? 'text-gray-700' : 'text-gray-600',
        menu_level == 0 ? 'hover:text-gray-900' : 'hover:bg-gray-50',
        'transition-colors',
        'duration-200',
        menu_level > 0 ? 'block px-4 py-2 text-sm' : '',
        item.in_active_trail ? 'font-semibold text-gray-900',
      ] %}
      {% set li_classes = [
        'relative',
        item.below ? 'group' : '',
      ] %}
      <li{{ item.attributes.addClass(li_classes) }}>
        <a href="{{ item.url }}" class="{{ item_classes|join(' ') }}">{{ item.title }}</a>
        {% if item.below %}
          {{ menus.menu_links(item.below, attributes, menu_level + 1) }}
        {% endif %}
      </li>
    {% endfor %}
    {% if menu_level > 0 %}
        </div>
    {% endif %}
    </ul>
  {% endif %}
{% endmacro %}
```

**Key Features:**
- **Horizontal layout** for top-level items: `flex space-x-6 items-center`
- **Dropdown functionality**: Uses `group` and `group-hover:block` for hover-triggered dropdowns
- **Seamless hover**: `pt-2` padding eliminates gap between parent and dropdown
- **Dropdown styling**: White background, shadow, border, rounded corners
- **Hover effects**: Color change for top-level, background change for dropdown items
- **Active trail**: Bold text for current page

3. Rebuild Tailwind CSS to include new utility classes:
```bash
ddev exec "cd web/themes/custom/<theme_name> && npm run build"
```

4. Clear caches:
```bash
ddev drush cache:rebuild
```

## Phase 6: Verification

1. Clear all caches:
```bash
ddev drush cache:rebuild
```

2. Launch site:
```bash
ddev launch
```

3. Verify:
   - Logo displays (or none if not uploaded)
   - Site name displays (from config)
   - Menu renders with links (from menu block in header region)

4. Test dynamic updates:
   - Check site name: `ddev drush config:get system.site name`
   - Visit admin: `/admin/config/system/site-information`
   - Visit theme settings: `/admin/appearance/settings/<theme_name>`
   - Visit menu management: `/admin/structure/menu/manage/main`

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

# Retry Policy

If any step fails:
1. Log the error to `RETROSPECTIVE.md`
2. Attempt to fix the issue automatically (if possible)
3. Retry up to 3 times
4. If all retries fail, exit with clear error message

# Success Criteria

- ✅ SDC component created with valid YAML schema
- ✅ Preprocess hook added to theme file
- ✅ Page template updated to use SDC with props
- ✅ Caches cleared successfully
- ✅ Site displays header with logo, site name, and menu
- ✅ Menu remains editable via Drupal admin UI

# Notes

**Menu Handling:** Menu is fetched using Menu Tree API in the preprocess hook and passed as a render array prop to the SDC. Menu remains fully editable via Drupal admin UI (`/admin/structure/menu`).

**Mobile Menu:** Current implementation displays the menu on all screen sizes. For mobile-specific navigation patterns (hamburger menu, slide-out drawer, etc.), a follow-up skill can be created to add responsive menu behavior with JavaScript.

**Styling Flexibility:** Tailwind classes in SDC can be customized. Consider utility classes for:
- Background color: `bg-white`, `bg-gray-50`
- Shadow: `shadow-sm`, `shadow-md`
- Spacing: `py-4 px-6`, `py-6 px-8`

**SEO & Accessibility:**
- Logo has proper `alt` attribute
- Site name in semantic heading (consider `<h1>` if homepage)
- Menu wrapped in `<nav>` (from existing menu templates)

# Post-Execution

After successful execution:
1. Restore DDEV snapshot if needed: `ddev snapshot restore <snapshot_name>`
2. Update `RETROSPECTIVE.md` with any issues encountered
3. Verify all files are committed to git
