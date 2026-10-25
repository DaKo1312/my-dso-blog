---
sidebar_position: 1
---

# Docusaurus Blog

This page documents how I turned the Developer Akademie blog template into my own
learning journal, and which configuration steps were necessary to get it published
on GitHub Pages.

## TOC

- [Quickstart](#quickstart)
- [Description](#description)
  - [Environment configuration](#environment-configuration)
  - [Site configuration](#site-configuration)
  - [Documentation](#documentation)
  - [Repository settings](#repository-settings)
- [Further References](#further-references)

import GithubLinkAdmonition from '@site/src/components/GithubLinkAdmonition';

<GithubLinkAdmonition
    link="https://github.com/DaKo1312/my-dso-blog"
    title="Github Tip"
    type="tip"
>
Checkout this repository to see the code/implementation
</GithubLinkAdmonition>

## Quickstart

1. Create your own repository from the template and clone it.
2. Install the dependencies with `npm install`.
3. Copy `example.env` to `.env` and adjust the values to your own repository.
4. Start the development server with `npm start`.
5. Verify that the production build works with `npm run build`.

## Description

All changes were made on a dedicated feature branch named `setup-blog` and merged back
into the main branch through a pull request.

### Environment configuration

The build pipeline copies `example.env` to `.env` before building the site, which means
`example.env` holds the values the published site is built with. The template defaults
still pointed at the original author's repository, so they had to be replaced:

- `DEPLOYMENT_URL` and `BASE_URL` now match my GitHub Pages address and project name.
- `GITHUB_ORG` and `GITHUB_PROJECT` now reference my account and repository.
- `GIT_REPOSITORY_URL` was added so the repository URL is configurable instead of
  being hardcoded in several places.

Because this file is committed, it must never contain secrets. Real credentials belong
in `.env`, which is excluded from version control.

### Site configuration

In `docusaurus.config.ts` a `gitRepositoryUrl` constant reads the new environment
variable and falls back to the repository URL, following the pattern already used by
the existing `blogEnabled` constant. It feeds the "edit this page" links of both the
docs and the blog section, as well as the GitHub link in the navigation bar.

Beyond that, the site identity was personalised: `title`, `tagline`, the navigation bar
title and the logo alt text. The footer received a link to the projects overview, the
Community column was removed, and the More column now links to this repository and to
the template it is based on. The copyright notice names me and states that the site is
extended from the developer-akademie-starter.

One detail is worth mentioning: the blog link was appended to the footer by its numeric
column index. Removing the Community column shifts that index, so the lookup was changed
to search the column by its title instead.

### Documentation

The deployment section of the `README.md` was replaced with a short description of the
automated workflow, and the passages that referenced the removed instructions were
adjusted accordingly. The contributing section was removed, as this project does not
accept contributions.

### Repository settings

For the workflow to publish anything, the repository itself has to allow it. Under
*Settings → Pages → Build and deployment*, the source has to be set to **GitHub Actions**.

## Further References

- [Docusaurus documentation](https://docusaurus.io/docs)
- [Deploying a Docusaurus site](https://docusaurus.io/docs/deployment)
- [GitHub Pages documentation](https://docs.github.com/en/pages)
