# Cloudflare Pages release history integration

FocusLite publishes its release catalog at:

```text
https://peixinlu.github.io/FocusLite/releases.json
```

The catalog includes version, publication time, Markdown notes, stable release-note URL, GitHub Release URL, and download URL. Releases are ordered newest first.

## Recommended build-time integration

Fetch the catalog in the website build and render the `releases` array as a timeline. A minimal JavaScript fetch looks like this:

```js
const response = await fetch("https://peixinlu.github.io/FocusLite/releases.json");
if (!response.ok) {
  throw new Error(`Failed to load FocusLite releases: ${response.status}`);
}

const { releases } = await response.json();
```

Use `notesMarkdown` when the website already has a Markdown renderer, or link to `notesUrl` for the pre-rendered release page.

## Automatic rebuild

1. In Cloudflare, open **Workers & Pages → the website project → Settings → Builds → Deploy hooks**.
2. Create a hook for the production branch.
3. In the FocusLite GitHub repository, open **Settings → Secrets and variables → Actions**.
4. Add a repository secret named `CF_PAGES_DEPLOY_HOOK_URL` whose value is the hook URL.

The release and republish workflows call this hook only after the updated catalog has been deployed. The secret is optional, and its absence does not fail a FocusLite release.

The deploy hook URL grants permission to trigger builds. Keep it in GitHub Actions secrets and do not commit it to either repository.
