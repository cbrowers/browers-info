# browers.info

Source of [www.browers.info](https://www.browers.info): Hugo + [Blowfish](https://blowfish.page) theme.

## Publish a post

1. Create a page bundle: `content/posts/YYYY-MM-slug/index.md` (images go next to it).
   With Hugo installed: `hugo new content posts/2026-12-my-post/index.md`.
2. Front matter:
   ```yaml
   ---
   title: "My post"
   date: 2026-12-01
   draft: false          # true = not built (safe to push WIP)
   summary: "One-line teaser for cards, RSS and social previews"
   tags: ["llm"]
   series: ["My series"] # optional, groups multi-part tutorials
   ---
   ```
3. `git push` to `main` → GitHub Actions builds the image → the server picks it up
   within the pull-timer interval (see below).

Future-dated posts are published by the daily scheduled rebuild (05:00 UTC).

### Diagrams

```
{{< mermaid >}}
flowchart LR
  A --> B
{{< /mermaid >}}
```

Code blocks get syntax highlighting and a copy button automatically.

## Local preview

```bash
# same Hugo version as CI, no local install needed
docker run --rm -it -p 1313:1313 -v "$PWD":/project ghcr.io/gohugoio/hugo:v0.167.0 \
  server --bind 0.0.0.0 -D
# → http://localhost:1313
```

Or test the production container: `docker build -t blog . && docker run --rm -p 8080:8080 blog`.

## How it is deployed

```
git push → Actions: docker build (hugo → nginx-unprivileged) → ghcr.io/cbrowers/browers-info:latest
        → Hetzner server: blog-update.timer pulls the image → container restarts if changed
```

Server side (compose file, systemd timer, Traefik routing) lives in the private
`docker-infra` repo under `services/blog/`; deploy changes there with
`make deploy-blog SERVER=<ip>`.

**Rollback:** `git revert` the bad commit and push. Every build is also tagged with
its commit SHA in GHCR.

## Maintenance

- Theme is a Hugo module pinned in `go.mod`. Dependabot opens PRs for the theme,
  base images and actions; PRs are build-checked by CI.
- Keep the Hugo version in `Dockerfile` within the range Blowfish supports
  (see the theme's release notes).
- Comments: [giscus](https://giscus.app), stored in this repo's Discussions → "Comments".
