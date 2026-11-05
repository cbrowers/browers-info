---
title: "Hello, world"
date: 2026-11-05
draft: false
summary: "Why this blog exists and what to expect: hands-on AI/ML tutorials and architecture notes."
tags: ["meta"]
---

This is the first post on **browers.info** — a test of the publishing pipeline:
I push a Markdown file to GitHub, and a few minutes later it's live.

## How this site works

{{< mermaid >}}
flowchart LR
  A[Markdown in GitHub] -->|git push| B[GitHub Actions<br/>hugo build]
  B --> C[(GHCR image)]
  C -->|pulled by timer| D[nginx container<br/>on Hetzner]
  D --> E((Reader))
{{< /mermaid >}}

## Code works too

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"

print(greet("world"))
```

Comments are below — sign in with GitHub.
