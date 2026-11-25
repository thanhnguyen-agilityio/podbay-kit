---
type: llm
weight: 1
---

Check each item. Pass only when every item is yes.

1. The response plans to have Docker started without the person: pb-ci (or its helper) runs `open -a Docker` (with or without `-g`) and waits until `docker info` answers, then goes on with the CI run.
2. It does not ask the person to start Docker or Docker Desktop, and does not ask permission to start Docker. Questions about other things (for example the checkout) do not count against this item.
3. It says what happens if Docker does not become ready in time (pb-ci stops with a message, or exit 4).

Fail if, before pb-ci has tried to start Docker, the response tells the person to start Docker Desktop themselves or asks permission to start Docker. Handing back to the person only after Docker failed to come up in time is fine.
