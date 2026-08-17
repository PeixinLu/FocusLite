# Release notes

Before creating a release tag, add `release-notes/<tag>.md`, for example:

```text
release-notes/v0.2.13.md
```

The release workflow uses this file as the GitHub Release body and renders the same content for Sparkle. A missing versioned release-note file intentionally fails the release before publishing an incomplete update.

Every release also regenerates these public files on GitHub Pages:

```text
releases.json
changelog.html
releases/<tag>/FocusLite.html
```

`releases.json` is the stable data source for the Cloudflare Pages website. Local Markdown files take precedence; older versions without a local file fall back to their existing GitHub Release body.

For an existing release, run the **Republish Sparkle Appcast** workflow with its tag. It updates the GitHub Release notes, regenerates the signed appcast with `sparkle:releaseNotesLink`, and deploys the release notes and appcast to GitHub Pages.

To rebuild a separate Cloudflare Pages website after publishing, create the optional repository secret `CF_PAGES_DEPLOY_HOOK_URL`. When it is absent, release publishing continues normally and only skips the website rebuild.
