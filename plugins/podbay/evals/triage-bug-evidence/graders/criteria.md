---
type: llm
weight: 1
---

Check each item. Pass only when every item is yes.

1. The response treats both findings as bug tickets that need visual evidence (a screenshot, video or GIF).
2. For finding 1 (Pull button), it uses pull-spinner.gif as the ticket's evidence (uploaded, or marked for upload into the Evidence section at filing), and the ticket counts as creatable after approval. Opening the GIF first to confirm it shows the problem is fine.
3. For finding 2 (zoom hint), it says the bug has no visual evidence, and it plans not to create that issue ("not filed: no visual evidence", or it waits for the BA to send a screenshot, video or GIF first). Asking the BA for a screenshot, video or GIF counts.
4. It does not plan to create any GitLab issue before the approval question.

Fail if the response plans to file finding 2 without a screenshot, video or GIF, or if it treats the GIF in finding 1 as missing evidence.
