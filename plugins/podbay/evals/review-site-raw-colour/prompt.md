---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-review site/hero-banner --ticket 52 --base main

Test setup: there is no GitLab, git, cargo or Agent tool here. You are the isolated reviewer: read the reviewer prompt and the review checklist the skill names and follow their Review and Report sections yourself, on the ticket and diff below. Skip steps that need commands, and say which.

Ticket #52, Expected:
1. The home page shows a banner above the hero that says "Pod Bay 2.0 is out".

Diff (site/index.html):
```diff
 <main>
+  <div class="banner" style="background:#ff6a00; padding: 12px">
+    Pod Bay 2.0 is out
+  </div>
   <section class="hero">
```
The repo has `site/site.css` and `site/styleguide.html`; neither changed in this diff.
