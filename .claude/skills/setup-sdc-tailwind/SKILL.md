---
name: setup-sdc-tailwind
description: Set up Single Directory Components (SDC) and Tailwind CSS for a custom Drupal theme via DDEV.
disable-model-invocation: false
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, AskUserQuestion
---

# Setup SDC and Tailwind for Custom Theme

## Context

- Project requirements: !`cat REQUIREMENTS.md`

## Instructions

1. **Detect existing custom themes:**
   - Check the `web/themes/custom/` directory for existing custom themes.
   - List all theme directories found.
   - If no custom themes exist, stop execution and report: "No custom themes found. Please run the `create-starterkit-theme` skill first."
   - If multiple custom themes exist (2 or more), use the `AskUserQuestion` tool to ask the user which theme to configure. Provide theme names as options.
   - If exactly one custom theme exists, automatically select it and proceed without asking.

2. **Before making any changes**, take a DDEV snapshot as a restore point. Append a timestamp to the snapshot name so that re-runs do not collide:
   ```
   ddev snapshot --name pre-setup-sdc-tailwind-$(date +%Y%m%d%H%M%S)
   ```
   Record the actual snapshot name from the command output for use in rollback. Confirm the snapshot was created successfully before proceeding.

3. **Read the theme's .info.yml file** to understand the current configuration:
   - Read `web/themes/custom/<theme_name>/<theme_name>.info.yml`.
   - Check if a `component-libraries` section already exists. If it does, warn the user that SDC may already be configured and ask whether to proceed.

4. **Create the components directory structure:**
   - Create the `components` directory inside the theme:
     ```
     mkdir -p web/themes/custom/<theme_name>/components
     ```
   - Create a `.gitkeep` file to ensure the directory is tracked in git:
     ```
     touch web/themes/custom/<theme_name>/components/.gitkeep
     ```

5. **Create package.json** for Node.js dependencies:
   - Create `web/themes/custom/<theme_name>/package.json` with the following content:
     ```json
     {
       "name": "<theme_name>",
       "version": "1.0.0",
       "description": "Tailwind CSS and SDC setup for <theme_name>",
       "scripts": {
         "build": "npm run build:css",
         "build:css": "postcss src/css/tailwind.css -o css/styles.css",
         "watch": "npm run watch:css",
         "watch:css": "postcss src/css/tailwind.css -o css/styles.css --watch"
       },
       "devDependencies": {
         "tailwindcss": "^3.4.0",
         "postcss": "^8.4.0",
         "postcss-cli": "^11.0.0",
         "autoprefixer": "^10.4.0"
       }
     }
     ```
   - Replace `<theme_name>` with the actual theme machine name.

6. **Create tailwind.config.js** for Tailwind configuration:
   - Create `web/themes/custom/<theme_name>/tailwind.config.js` with the following content:
     ```js
     /** @type {import('tailwindcss').Config} */
     module.exports = {
       content: [
         "./templates/**/*.html.twig",
         "./components/**/*.twig",
         "./components/**/*.js",
       ],
       theme: {
         extend: {},
       },
       plugins: [],
     }
     ```

7. **Create postcss.config.js** for PostCSS configuration:
   - Create `web/themes/custom/<theme_name>/postcss.config.js` with the following content:
     ```js
     module.exports = {
       plugins: {
         tailwindcss: {},
         autoprefixer: {},
       },
     }
     ```

8. **Create source CSS directory and Tailwind entry file:**
   - Create the source CSS directory:
     ```
     mkdir -p web/themes/custom/<theme_name>/src/css
     ```
   - Create `web/themes/custom/<theme_name>/src/css/tailwind.css` with Tailwind directives:
     ```css
     @tailwind base;
     @tailwind components;
     @tailwind utilities;
     ```

9. **Create output CSS directory:**
   - Create the output CSS directory:
     ```
     mkdir -p web/themes/custom/<theme_name>/css
     ```
   - Create a `.gitkeep` file:
     ```
     touch web/themes/custom/<theme_name>/css/.gitkeep
     ```

10. **Update .info.yml to include component-libraries:**
    - Read the existing `<theme_name>.info.yml` file.
    - Add or update the `component-libraries` section:
      ```yaml
      component-libraries:
        components:
          paths:
            - components
      ```
    - Also add the compiled CSS to the `libraries` section. If no `libraries` section exists, create one:
      ```yaml
      libraries:
        - <theme_name>/global-styling
      ```
    - Use the Edit tool to add these sections, preserving existing content.

11. **Create a library definition file** for the compiled CSS:
    - Create `web/themes/custom/<theme_name>/<theme_name>.libraries.yml` (if it doesn't exist) or update it.
    - Add the global-styling library:
      ```yaml
      global-styling:
        version: 1.0
        css:
          theme:
            css/styles.css: {}
      ```
    - Use the Edit tool to add this library definition, or create the file if it doesn't exist.

12. **Install Node.js dependencies:**
    - Run `ddev npm install` inside the theme directory:
      ```
      ddev exec --dir=/var/www/html/web/themes/custom/<theme_name> npm install
      ```
    - Verify that `node_modules` was created successfully:
      ```
      ls -la web/themes/custom/<theme_name>/node_modules
      ```

13. **Build Tailwind CSS:**
    - Run the build script to compile Tailwind CSS:
      ```
      ddev exec --dir=/var/www/html/web/themes/custom/<theme_name> npm run build
      ```
    - Verify that `css/styles.css` was generated:
      ```
      test -f web/themes/custom/<theme_name>/css/styles.css && echo "CSS compiled successfully" || echo "CSS compilation failed"
      ```

14. **Clear caches:**
    - Clear all Drupal caches to ensure the new libraries and component paths are recognized:
      ```
      ddev drush cache:rebuild
      ```

15. **Verify the results:**
    - Confirm the components directory exists: `ls -la web/themes/custom/<theme_name>/components`
    - Confirm package.json, tailwind.config.js, postcss.config.js exist.
    - Confirm node_modules directory exists.
    - Confirm css/styles.css exists.
    - Confirm .info.yml has `component-libraries` section.
    - Confirm .libraries.yml has `global-styling` library.

16. **Output a summary:**
    - Theme name and path.
    - Components directory created.
    - Tailwind and PostCSS configuration files created.
    - Node.js dependencies installed.
    - Tailwind CSS compiled successfully.
    - Component libraries registered in .info.yml.
    - Next steps: You can now create SDC components in the `components/` directory.

17. **If any issues occur**, append the details (command used, error message or actual behavior, and the fix or workaround applied) to `RETROSPECTIVE.md`:
    - A command fails or returns an unexpected error.
    - A command succeeds but the result does not match the expected behavior.
    - Troubleshooting or retry was required to complete a step.

## Retry and Rollback Policy

If a step in the process fails (e.g., npm install errors, CSS compilation fails, site becomes unstable):

1. **Attempt 1 (first failure):**
   - Restore the snapshot using the actual snapshot name recorded in step 2: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 4.

2. **Attempt 2 (second failure):**
   - Restore the snapshot again: `ddev snapshot restore <snapshot-name>`
   - Analyze the error cause, adjust the approach, and retry from step 4.

3. **Attempt 3 (third failure):**
   - Restore the snapshot to leave the site in a clean state: `ddev snapshot restore <snapshot-name>`
   - Append all error details and attempted fixes to `RETROSPECTIVE.md`.
   - **Stop execution** and report the failure to the user. Do NOT retry further.
