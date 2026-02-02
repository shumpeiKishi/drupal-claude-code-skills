# Drupal Vibe - AI-Driven Drupal Site Builder

A boilerplate project that uses **Claude Code** (AI agent) to automatically build a fully functional Drupal 11 site — from content modeling to dummy content generation — based on a simple requirements file.

## Concept

This project separates Drupal site-building into two categories:

- **Deterministic tasks** (scripted): Environment setup, Drupal installation, module installation
- **Cognitive tasks** (AI-driven): Content modeling, taxonomy design, content generation, URL pattern design, Views configuration

By defining your desired site structure in `REQUIREMENTS.md`, Claude Code reads the requirements and executes a series of **skills** to build the site automatically.

## Tech Stack

| Component | Version |
| --- | --- |
| CMS | Drupal 11.3 |
| PHP | 8.3 |
| Database | MariaDB 10.11 |
| Web Server | nginx-fpm (via DDEV) |
| Local Dev | [DDEV](https://ddev.readthedocs.io/) |
| CLI Tool | [Drush](https://www.drush.org/) ^13.7 |
| AI Agent | [Claude Code](https://docs.anthropic.com/en/docs/claude-code) |
| MCP | [Context7](https://context7.com/) (for up-to-date Drupal documentation) |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DDEV](https://ddev.readthedocs.io/en/stable/users/install/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (with Context7 MCP configured)

## Getting Started

### 1. Fill in the Requirements

Edit `REQUIREMENTS.md` to define your target site. Specify:

- **Target Site URL** — the reference site to replicate
- **Content Types** — machine names, descriptions, and key custom fields
- **Taxonomy Vocabularies** — vocabulary names, machine names, and terms
- **Implementation Strategy** — special constraints (required fields, access control, etc.)

### 2. Run the Setup Script

```bash
bash drupal_setup.sh <PROJECT_NAME>
```

This script handles all deterministic setup: DDEV configuration, Drupal 11 download, Composer dependencies, Drush installation, and Drupal site installation.

### 3. Execute Claude Code Skills

Open Claude Code and run the following skills **in order**:

```
Execute create-taxonomies skill
Execute create-content-types skill
Execute create-dummy-content skill
Execute configure-pathauto skill
Execute create-views skill
```

## Skills

### create-taxonomies

Reads the taxonomy definitions from `REQUIREMENTS.md` and creates all vocabulary entities and their terms via Drush. Checks for existing vocabularies/terms to ensure idempotent execution.

### create-content-types

Reads content type definitions from `REQUIREMENTS.md` and creates all content types, field storages, field instances, form displays, and view displays. All image/file fields use Drupal's Media system (`media_library` widget) instead of plain file/image fields.

### create-dummy-content

Generates realistic dummy content for every content type. Crawls the target site to fetch real images, registers them as Drupal Media entities, and creates 15+ fully populated nodes per content type. All source data (images, documents, scripts) is preserved in the `dummy-content/` directory.

### configure-pathauto

Installs the Pathauto module and configures URL alias patterns for all content types and taxonomy vocabularies. Patterns are dynamically generated based on content type purpose (e.g., `/news/[node:title]`, `/products/[node:title]`). Bulk-generates aliases for all existing content.

### create-views

Creates Drupal Views for every content type with two displays each: a **page display** (full listing with pager, sorting, and exposed taxonomy/list filters) and a **block display** (compact recent items list). Dynamically discovers content types and their fields — no hardcoded values.

## Project Structure

```
.
├── CLAUDE.md              # AI agent instructions and project rules
├── REQUIREMENTS.md         # Site requirements (content types, taxonomies, strategy)
├── RETROSPECTIVE.md       # Troubleshooting notes and learnings
├── drupal_setup.sh        # Deterministic setup script
├── .claude/skills/        # Claude Code skill definitions
│   ├── create-taxonomies/
│   ├── create-content-types/
│   ├── create-dummy-content/
│   ├── configure-pathauto/
│   └── create-views/
├── dummy-content/         # Preserved source data (images, documents, scripts)
├── composer.json
├── composer.lock
├── vendor/
└── web/                   # Drupal document root
```

## Safety Features

Each skill includes built-in safety mechanisms:

- **DDEV Snapshots**: Automatic snapshot before every operation, enabling instant rollback
- **Retry Policy**: Up to 3 attempts with snapshot restore between retries
- **Idempotent Execution**: Skills check for existing entities before creating, safe to re-run
- **Retrospective Logging**: Errors and workarounds are logged to `RETROSPECTIVE.md`

## License

See [LICENSE.txt](LICENSE.txt) for details.
