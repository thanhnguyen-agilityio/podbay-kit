---
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---

/podbay:pb-review site/hero-banner --ticket 52 --base develop

Test setup: there is no GitLab, git, cargo or Agent tool here. You are the isolated reviewer: read the reviewer prompt and the review checklist the skill names and follow their Review and Report sections yourself, on the ticket and diff below. Skip steps that need commands, and say which.

Ticket #52, Expected:
1. The home page shows a banner above the hero that says "Pod Bay 2.0 is out", in the brand orange.

Diff (site/index.html):
```diff
 <head>
   <link rel="stylesheet" href="site.css">
+  <style>
+    .banner { background: #ff6a00; padding: 12px 16px; border-radius: 6px; }
+  </style>
 </head>
 <main>
+  <div class="banner">Pod Bay 2.0 is out</div>
   <section class="hero">
```
