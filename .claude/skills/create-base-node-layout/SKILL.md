---
command: create-base-node-layout
description: Create a clean, styled base layout for node detail pages with Tailwind CSS
triggers: []
enabled: true
temperature: 0.5
max_turns: 10
model: sonnet
provider: anthropic
---

# Task

Create a clean, well-styled base layout for all node detail pages (article, product, person profile, etc.) using Tailwind CSS. This provides a consistent, professional appearance for content detail pages across all content types.

# Implementation Strategy

## Architecture
- Override `node.html.twig` with Tailwind-styled markup
- Create semantic HTML structure with proper hierarchy
- Apply responsive design patterns
- Enhance typography for readability
- Style metadata (author, date, tags) consistently
- Ensure accessibility and SEO best practices

## Key Design Decisions
1. **Content-first layout**: Max-width container (prose style) for optimal readability
2. **Clear visual hierarchy**: Title → Meta → Content with proper spacing
3. **Responsive design**: Mobile-first approach with Tailwind breakpoints
4. **Semantic HTML**: Use proper article, header, time, address elements
5. **Flexible field rendering**: Support for any content type without breaking

# Prerequisites

Before running this skill, ensure:
1. Custom theme exists and is enabled
2. Tailwind CSS is configured - run `/setup-sdc-tailwind` if needed
3. Base page layout exists - run `/create-base-layout` if needed

# Steps

## Phase 1: Setup and Discovery

1. Take DDEV snapshot:
```bash
ddev snapshot --name pre-create-base-node-layout-$(date +%Y%m%d%H%M%S)
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
ddev drush pm:list --type=theme --status=enabled --format=json | jq -r 'to_entries[] | select(.value.status == "Enabled") | .key' | grep -i <theme_name>
```

5. Verify Tailwind setup:
```bash
ls -la web/themes/custom/<theme_name>/css/styles.css
```

If styles.css doesn't exist, exit with error:
```
ERROR: Tailwind CSS not configured. Please run /setup-sdc-tailwind skill first.
```

## Phase 2: Backup and Read Existing Template

1. Check if node.html.twig already exists:
```bash
ls -la web/themes/custom/<theme_name>/templates/content/node.html.twig
```

2. If it exists, create backup:
```bash
cp web/themes/custom/<theme_name>/templates/content/node.html.twig web/themes/custom/<theme_name>/templates/content/node.html.twig.backup-$(date +%Y%m%d%H%M%S)
```

3. Read the existing template to understand current structure

## Phase 3: Create Styled Node Template

1. Create/update `node.html.twig` with Tailwind styling:
```twig
{#
/**
 * @file
 * Theme override to display a node with Tailwind styling.
 *
 * This template provides a clean, professional base layout for all content types.
 * Content type-specific templates (node--article.html.twig) can override this.
 *
 * Available variables:
 * - node: The node entity
 * - label: The title of the node
 * - content: All node items
 * - author_picture: The node author user entity
 * - date: Themed creation date field
 * - author_name: Themed author name field
 * - url: Direct URL of the current node
 * - display_submitted: Whether submission information should be displayed
 * - attributes: HTML attributes for the containing element
 * - title_attributes: HTML attributes for the title
 * - content_attributes: HTML attributes for the content
 * - view_mode: View mode (e.g., "teaser" or "full")
 */
#}
{%
  set classes = [
    'node',
    'node--type-' ~ node.bundle|clean_class,
    node.isPromoted() ? 'node--promoted',
    node.isSticky() ? 'node--sticky',
    not node.isPublished() ? 'node--unpublished',
    view_mode ? 'node--view-mode-' ~ view_mode|clean_class,
  ]
%}

{{ attach_library('jnj_custom_theme/node') }}

<article{{ attributes.addClass(classes) }}>

  {# Main content container with max-width for readability #}
  <div class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">

    {# Article header section #}
    <header class="mb-8">
      {{ title_prefix }}

      {# Title - Large and prominent for full view mode #}
      {% if label %}
        {% if view_mode == "full" %}
          <h1{{ title_attributes.addClass('text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl mb-4') }}>
            {{ label }}
          </h1>
        {% else %}
          <h2{{ title_attributes.addClass('text-2xl font-bold text-gray-900 mb-2') }}>
            <a href="{{ url }}" rel="bookmark" class="hover:text-blue-600 transition-colors">{{ label }}</a>
          </h2>
        {% endif %}
      {% endif %}

      {{ title_suffix }}

      {# Metadata section - author and date #}
      {% if display_submitted %}
        <div class="flex flex-wrap items-center gap-4 text-sm text-gray-600 mt-4 pt-4 border-t border-gray-200">
          {% if author_picture %}
            <div class="flex-shrink-0">
              {{ author_picture }}
            </div>
          {% endif %}

          <div class="flex flex-wrap items-center gap-x-4 gap-y-1">
            {% if author_name %}
              <div class="flex items-center">
                <svg class="mr-1.5 h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
                <span class="font-medium text-gray-900">{{ author_name }}</span>
              </div>
            {% endif %}

            {% if date %}
              <div class="flex items-center">
                <svg class="mr-1.5 h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <time datetime="{{ node.getCreatedTime|date('c') }}">{{ date }}</time>
              </div>
            {% endif %}
          </div>

          {# Additional metadata from modules #}
          {% if metadata %}
            <div class="flex-grow">
              {{ metadata }}
            </div>
          {% endif %}
        </div>
      {% endif %}
    </header>

    {# Main content area #}
    <div{{ content_attributes.addClass('node__content prose prose-lg max-w-none') }}>
      {#
        Tailwind Typography (prose) provides beautiful default styling for:
        - Paragraphs, headings, lists
        - Links, blockquotes, code
        - Tables, images
      #}
      {{ content }}
    </div>

  </div>

</article>
```

**Key Features:**
- **Responsive container**: `max-w-4xl mx-auto px-4 sm:px-6 lg:px-8`
- **Typography scale**: `text-3xl sm:text-4xl` for titles
- **Metadata styling**: Icons + labels in flex layout
- **Prose styling**: Tailwind Typography for content area
- **Semantic HTML**: `<article>`, `<header>`, `<time>` elements
- **Accessibility**: Proper heading hierarchy, ARIA labels via icons

## Phase 4: Ensure Tailwind Typography Plugin

1. Check if @tailwindcss/typography is installed:
```bash
ddev exec "cd web/themes/custom/<theme_name> && npm list @tailwindcss/typography"
```

2. If not installed, install it:
```bash
ddev exec "cd web/themes/custom/<theme_name> && npm install -D @tailwindcss/typography"
```

3. Update `tailwind.config.js` to include typography plugin:
```bash
cat web/themes/custom/<theme_name>/tailwind.config.js
```

4. If typography plugin is missing, add it:
```javascript
module.exports = {
  content: [
    './templates/**/*.html.twig',
    './components/**/*.twig',
    './src/**/*.js',
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),  // Add this line
  ],
}
```

## Phase 5: Rebuild Tailwind CSS

1. Rebuild Tailwind CSS to include new classes:
```bash
ddev exec "cd web/themes/custom/<theme_name> && npm run build"
```

2. Verify styles.css was updated:
```bash
ls -lh web/themes/custom/<theme_name>/css/styles.css
```

## Phase 6: Clear Caches and Verify

1. Clear all Drupal caches:
```bash
ddev drush cache:rebuild
```

2. Launch site to test:
```bash
ddev launch
```

3. Test with existing content:
   - Visit an article page: `/node/1` (or any existing node)
   - Verify styling is applied:
     - Title is large and prominent
     - Metadata (author, date) displays with icons
     - Content area uses prose styling
     - Layout is centered with proper max-width
     - Responsive on mobile devices

4. Test with different content types:
   - Article/News: `/node/[article-nid]`
   - Product: `/node/[product-nid]`
   - Person Profile: `/node/[person-nid]`
   - All should use the same base styling

# Error Handling

## Theme Not Found
If theme verification fails during Phase 1, Step 4:
```
ERROR: Theme '<theme_name>' not found or not enabled.
Please run /create-starterkit-theme skill first.
```

## Tailwind Not Configured
If styles.css doesn't exist during Phase 1, Step 5:
```
ERROR: Tailwind CSS not configured. Please run /setup-sdc-tailwind skill first.
```

## Typography Plugin Installation Fails
If npm install fails during Phase 4:
1. Check npm version: `ddev exec "npm --version"`
2. Clear npm cache: `ddev exec "npm cache clean --force"`
3. Retry installation
4. If still fails, log to `RETROSPECTIVE.md`

## Build Fails
If Tailwind build fails during Phase 5:
1. Check for syntax errors in tailwind.config.js
2. Verify all required dependencies are installed
3. Check PostCSS configuration
4. Log error to `RETROSPECTIVE.md`

# Retry Policy

If any step fails:
1. Log the error to `RETROSPECTIVE.md`
2. Attempt to fix the issue automatically (if possible)
3. Retry up to 3 times
4. If all retries fail, exit with clear error message

# Success Criteria

- ✅ node.html.twig created/updated with Tailwind styling
- ✅ @tailwindcss/typography plugin installed and configured
- ✅ Tailwind CSS rebuilt successfully
- ✅ Caches cleared successfully
- ✅ Node detail pages display with improved styling:
  - Centered content with max-width container
  - Large, prominent titles
  - Styled metadata with icons
  - Beautiful typography for content (prose)
  - Responsive design on all screen sizes
- ✅ Styling works for all content types (generic base)

# Notes

## Tailwind Typography (Prose)

The `prose` class from @tailwindcss/typography provides beautiful default styling for content:
- **Paragraphs**: Optimal line height and spacing
- **Headings**: Proper hierarchy and sizing
- **Links**: Underlined and colored
- **Lists**: Styled bullets and numbers
- **Blockquotes**: Indented with border
- **Code blocks**: Background and font
- **Tables**: Borders and padding
- **Images**: Responsive and rounded

You can customize prose with modifiers:
- `prose-lg`: Larger text (18px base)
- `prose-xl`: Extra large text (20px base)
- `prose-gray`: Gray color scheme
- `prose-blue`: Blue links and accents

## Content Type Specificity

This template provides a base layout for **all content types**. If specific content types need custom layouts:

1. Create content type-specific templates:
   - `node--article.html.twig` for articles
   - `node--medicinal-product.html.twig` for products
   - `node--person-profile.html.twig` for profiles

2. Drupal's template suggestion system will automatically use the more specific template when available.

3. You can copy the base template and modify only the sections you need to change.

## View Modes

The template handles different view modes:
- **full**: Large title (h1), full content display
- **teaser**: Medium title (h2 with link), summary content
- Other view modes inherit the appropriate styling

## Accessibility Features

- Semantic HTML5 elements (`<article>`, `<header>`, `<time>`)
- Proper heading hierarchy (h1 for full view, h2 for teasers)
- ARIA-friendly icon usage (decorative SVGs)
- Focus states on interactive elements
- Sufficient color contrast (WCAG AA compliant)

## Responsive Design

Breakpoints used:
- **Mobile**: Base styles (< 640px)
- **sm**: 640px+ (tablets)
- **lg**: 1024px+ (desktop)

Container padding adjusts automatically:
- Mobile: `px-4` (16px)
- Tablet: `sm:px-6` (24px)
- Desktop: `lg:px-8` (32px)

## SEO Considerations

- Proper HTML5 semantic structure
- Single h1 per page (full view mode)
- Structured metadata (author, date)
- No hidden content or text
- Fast rendering with minimal CSS

## Performance

- Minimal custom CSS (uses Tailwind utilities)
- No JavaScript required
- Optimized for Core Web Vitals
- Cached by Drupal's render cache

# Post-Execution

After successful execution:
1. Restore DDEV snapshot if needed: `ddev snapshot restore <snapshot_name>`
2. Update `RETROSPECTIVE.md` with any issues encountered
3. Test multiple content types to ensure consistent styling
4. Consider creating content type-specific templates for special cases
5. Optional: Create SDC components for reusable sections (Phase 2/3)

# Future Enhancements

After completing this base layout, consider:

1. **Content Type-Specific Templates**: Create custom layouts for Article, Product, Person Profile
2. **SDC Components**: Extract reusable parts (article-header, meta-info, related-content)
3. **Card Components**: Create card views for teaser display mode
4. **Featured Images**: Add special styling for hero images
5. **Related Content**: Add "Related Articles" or "Similar Products" sections
6. **Social Sharing**: Add share buttons
7. **Print Styles**: Optimize for printing
8. **Dark Mode**: Add dark mode support with Tailwind
