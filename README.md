# My Developer Blog

This website is built using [Docusaurus](https://docusaurus.io/), a modern static website generator.

## Repository Description

This repository hosts a developer blog built with Docusaurus. It includes tools and scripts for creating, managing, and deploying static web content. The software supports rapid local development, customizable theming, and seamless deployment to platforms like GitHub Pages or NGINX.

## Table of Contents

- [My Developer Blog](#my-developer-blog)
  - [Repository Description](#repository-description)
  - [Table of Contents](#table-of-contents)
  - [Quickstart](#quickstart)
    - [Prerequisites](#prerequisites)
  - [Repository Structure](#repository-structure)
  - [Deployment](#deployment)

## Quickstart

### Prerequisites

- [Node.js](https://nodejs.org/) (v24 or later recommended)
- [Docker](https://www.docker.com/products/docker-desktop) (only required if you follow the [NGINX deployment guide](./docs/guides/deploy-docusaurus-with-docker-and-nginx.md))

1. Installation

   ```
   $ npm install
   ```

2. Local Development

   ```
   $ npm start
   ```

   This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

3. Build

   ```
   $ npm run build
   ```

   This command generates static content into the `build` directory and can be served using any static contents hosting service.

4. Deployment

   No manual step is required. Pushing to the main branch publishes the site automatically.

For detailed information about deploying this Docusaurus project, refer to the [Deployment](#deployment) section below.

## Repository Structure

The repository is organized as follows:

- `blog/`: Contains markdown files for blog posts. Blog-related metadata is automatically picked up by the Docusaurus configuration.
- `docs/`: Contains markdown files for documentation. These files are referenced in `sidebars.ts` to define the sidebar structure.
- `src/`: Contains custom React components, CSS, and JavaScript for additional functionality or theming.
- `static/`: Stores static assets (e.g., images, icons) served directly without processing.
- `sidebars.ts`: Configures the structure of sidebars in the documentation section.
- `docusaurus.config.ts`: Main configuration file for customizing and managing Docusaurus behavior.
- `example.env`: Template for the environment configuration. The deployment workflow copies it to `.env` before building, so it must never contain secrets.
- `build/`: Generated after running the `npm run build` command. Contains the static website files ready for deployment.

New content can be added as follows:

- Add new documentation files to the `docs/` folder.
- Add new blog posts to the `blog/` folder. No additional configuration is required.

## Deployment

The website is deployed to GitHub Pages by a prepared GitHub Actions workflow. As soon as a commit is pushed to the main branch, the workflow builds the site and publishes the result, so no manual deployment step is needed.
