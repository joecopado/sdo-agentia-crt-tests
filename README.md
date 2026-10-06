# SDO Agentia CRT tests

Copado Robotic Testing suites for the **SDO Agentia Pipeline** (Copado CI/CD in the copado-trial org:
dev1 and dev2 -> QA -> Prod on the SDO org). Each test checks one user story's acceptance criteria in the
environment Copado just deployed to, and runs as a Copado quality gate after the deployment to QA.

| Test | User story | Checks |
|---|---|---|
| `tests/us_0000032_negative_amount.robot` | US-0000032 Block negative Opportunity amounts | an Opportunity with Amount -100 does not save; "Amount cannot be negative." shows; nothing is created |

Login (`resources/common.robot`): when Copado runs the test as a quality gate it passes `${loginUrl}`, a one-click
login to the destination org; otherwise the test logs in with the CRT job's JWT variables `client_id`, `username`,
`private_key` (set in CRT, never in this repo). The JWT variables also give the test API access for its database check.
