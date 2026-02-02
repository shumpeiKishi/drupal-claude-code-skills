

# Project Overview

This project aims to automatically build a Drupal site. Refer to `REQUIREMENTS.md` for detailed requirements (content types, taxonomy vocabularies, and implementation strategy) as needed.

# Environment

- **CMS**: Drupal 11.3 (`drupal/core-recommended: ^11.3`)
- **Local Development**: DDEV (project name: `drupal-vibe-xe`)
- **PHP**: 8.3
- **Database**: MariaDB 10.11
- **Web Server**: nginx-fpm
- **Document Root**: `web/`
- **Drush**: ^13.7

# Rules

- Comments on code must be in English.
- When you find areas for improvement in instructions or skills, or when you perform troubleshooting during work, append your findings to `RETROSPECTIVE.md` for future reference.
- When creating skills, make them generic and reusable across any Drupal project. Do not hardcode project-specific values (content types, taxonomy vocabularies, field names, URL patterns, etc.) into skills. Instead, have the skill dynamically read from `REQUIREMENTS.md` or the site's existing configuration at runtime.