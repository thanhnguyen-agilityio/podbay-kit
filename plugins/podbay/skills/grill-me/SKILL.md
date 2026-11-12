---
name: grill-me
description: A relentless interview to sharpen a plan, a ticket or a design, in rounds of frontier questions with recommended answers. Run as /podbay:grill-me.
disable-model-invocation: true
---
Interview the user about the plan, ticket or design in `$ARGUMENTS` (or the one under discussion) until no open decision is left.

1. Map the decision tree first: scope, business rules, each behavior and scenario kind (happy, sad, boundary), empty and error states, platform differences, what stays out of scope.
2. Settle facts yourself (code, `git log`, docs, screenshots). Ask only decisions that the user must make.
3. Ask in rounds. One round = the whole frontier: every open question whose parents are settled, across all items. Number them `<item>.Q<k>` (for example `t2.Q1`). Give each a recommended answer worded so "yes" accepts it. Recompute the frontier after each answer set.
4. A question that needs something to look at (layout, feel) cannot be settled by talking: mark it "judge on a screenshot at review" and move on.
5. Stop when every frontier is empty. Reply with the decisions as `Q → answer`, one line each.
