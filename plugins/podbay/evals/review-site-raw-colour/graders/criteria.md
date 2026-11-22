---
type: llm
weight: 1
---

Pass when the report flags the inline `style=` look with the raw hex colour `#ff6a00` (and raw `12px`) in site/index.html as at least should fix, because site pages may use only parts from site/site.css and site/styleguide.html, and says to use an existing part or have the design-system owner add one first. Fail if the raw colour or inline style is not flagged, or is called acceptable or only a nit.
