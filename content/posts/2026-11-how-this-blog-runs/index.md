---
title: "How this blog runs: Markdown in Git, a tiny container, and a pull-based deploy"
date: 2026-11-05
draft: false
summary: "The setup behind browers.info: Hugo and Blowfish, a hardened nginx container next to other self-hosted services, and a deploy pipeline that needs no inbound access to the server."
tags: ["hugo", "docker", "github-actions", "devops", "self-hosting"]
---

Before writing about AI/ML, I wanted a place to publish that costs almost nothing to run and gets out of the way when I write. This first real post describes how the site is built and deployed, and the decisions behind it.

## Requirements

- **Writing should be fast.** Markdown in my editor, `git push`, done.
- **Good support for technical content:** syntax highlighting, copy buttons on code blocks, diagrams, a table of contents, and series for multi-part tutorials.
- **Comments** without running a database or moderating sign-ups.
- **Self-hosted** on infrastructure I already operate, with as little ongoing maintenance as possible.
- **The original lives on my own domain.** Cross-posting to other platforms comes second, with a canonical link back here.

## Why a static site generator

I considered WordPress and Ghost. Both can do everything, but they bring a database, a runtime with its own patch cycle and, in WordPress's case, a plugin ecosystem that is a well-known attack surface. A blog that changes every few weeks doesn't need any of that.

A static site generator turns Markdown into plain HTML at build time. At runtime there is nothing to exploit except a web server serving files. I chose **[Hugo](https://gohugo.io)** because it is a single binary and builds this site in seconds. For the theme I chose **[Blowfish](https://blowfish.page)**, which ships with Mermaid diagrams, code copy buttons, series, a table of contents, search and dark mode, so I didn't have to build any of those myself.

**Comments** use [giscus](https://giscus.app), which stores them in GitHub Discussions on the site's repository. Readers sign in with GitHub, I moderate in GitHub, and there's no comment database for me to run.

## The architecture

{{< mermaid >}}
flowchart LR
  A["Markdown post"] -->|git push| B["GitHub repository"]
  B --> C["GitHub Actions: hugo build and docker build"]
  C --> D[("Container registry")]
  E["Timer on the server"] -->|pull new image| D
  E --> F["nginx container"]
  G["Reverse proxy with TLS"] --> F
  H(("Reader")) -->|HTTPS| G
{{< /mermaid >}}

The blog runs as one more container on a small cloud VM that already hosts a few other self-hosted services. A reverse proxy in front of all of them terminates TLS, obtains certificates from Let's Encrypt automatically, and applies the same security headers and rate limits to every service. Adding the blog meant adding a container with a few routing labels. No new server, no new certificate tooling.

## The build: one multi-stage Dockerfile

The entire build is a two-stage Dockerfile. The same file runs on my laptop and in CI, so a site that builds locally also builds in the pipeline.

```dockerfile
# Build stage: official Hugo image, pinned to a version the theme supports
FROM ghcr.io/gohugoio/hugo:v0.167.0 AS build
COPY --chown=hugo:hugo . /project
RUN hugo --gc --minify --environment production

# Runtime stage: only static files plus a non-root nginx
FROM nginxinc/nginx-unprivileged:1.30-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /project/public /usr/share/nginx/html
```

The final image contains no Hugo, no Go, no Node and no source, only HTML, CSS, JS and nginx.

The theme is pulled in as a **Hugo module** pinned in `go.mod`, not as a git submodule. My first attempt used a submodule and started downloading the theme's entire git history, including every demo image ever committed. A Hugo module downloads only the pinned release, and Dependabot can still open update PRs for it.

## The deploy: pull, don't push

The most common pattern for "push to deploy" is a CI job that SSHes into the server and restarts the service. I didn't want that. SSH on this server is reachable only from a small allowlist, and opening it to a CI provider's large, shifting IP ranges would mean storing an SSH key in my CI secrets. That would undo exactly the restriction I care about.

So the direction is reversed:

1. On every push to `main`, GitHub Actions builds the image and pushes it to a public container registry, tagged `latest` and with the commit SHA.
2. On the server, a **systemd timer** periodically runs `docker compose pull` and `docker compose up -d` for the blog.
3. If the image hasn't changed, `up -d` does nothing. If it has, the container is replaced in about a second.

```ini
[Service]
Type=oneshot
WorkingDirectory=/opt/blog
ExecStart=/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d --remove-orphans
```

This design has some useful properties:

- **No inbound deploy channel.** No webhook endpoint, no CI-held SSH key, no extra open port.
- **No registry credentials on the server.** The site is public anyway, so the image can be too.
- **Rollback is boring:** `git revert` and push. Every build is also kept under its commit SHA, so I can pin an older image if I ever need to.

The trade-off is latency: a post goes live at the next timer run, not instantly. For a blog that's fine. While setting things up I ran the timer every minute to iterate quickly, then relaxed the interval.

I also considered Watchtower and rejected it: it needs full access to the Docker socket, which the rest of my setup deliberately avoids, and the original project is no longer actively maintained.

## Hardening the container

Since the container only serves files, it can be locked down tightly:

```yaml
services:
  blog:
    image: ghcr.io/<owner>/<repo>:latest
    read_only: true            # root filesystem is immutable
    tmpfs: [/tmp]              # nginx needs a scratch dir for pid and temp files
    cap_drop: [ALL]            # no Linux capabilities at all
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits: { memory: 64m, cpus: '0.25' }
```

- **Non-root nginx** on an unprivileged port, so it needs no capabilities.
- **Read-only root filesystem.** Even a compromised nginx couldn't modify the site.
- **Resource limits** so the blog can never starve the other services on the same host.
- **No volumes and no state.** The container can be destroyed and recreated at any time. Content lives in Git, comments live in GitHub. There's nothing to back up.

One nginx detail is worth knowing if you run nginx behind a reverse proxy. By default nginx builds absolute redirect URLs, for example when adding a trailing slash, using *its own* port and scheme. Behind a proxy that can send visitors to `http://example.com:8080/posts/`. Two lines fix it:

```nginx
absolute_redirect off;
port_in_redirect off;
```

## Things that bit me

- **Theme and Hugo version ranges.** Blowfish declares a supported Hugo version range. Dependabot immediately proposed a newer Hugo that was outside it. I now ignore minor Hugo bumps in Dependabot and upgrade Hugo together with the theme, by hand.
- **CI concurrency groups.** I had one global concurrency group with `cancel-in-progress`. The first push to `main` was cancelled by Dependabot's PR builds, which landed in the same group. Scoping the group per branch (`build-${{ github.ref }}`) fixed it.
- **Mainline and stable images.** Dependabot also offered the mainline nginx release. I prefer the stable branch for something that just serves files, so that bump is also manual.

## What it costs to run

The blog uses a few megabytes of RAM on a server that was already running. The only recurring cost is the domain. Builds run on GitHub's free tier for public repositories.

## What's next

With the plumbing done, the next posts will be about what this blog is actually for: hands-on AI/ML tutorials and architecture notes. The source of this site is public, so if you want to copy the setup, the Dockerfile and workflow are on GitHub, linked from the edit button on each post.

If you have questions or would do something differently, the comments are open below.