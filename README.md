# CI/CD login proof branch

`resources/common.robot` is `main`'s resource file with `CICD And CRT Dynamic Login` reworked: under Copado CI/CD
the browser opens the loginUrl and QForce's API keywords get the same session (no JWT, any environment); run on
its own in CRT, it signs in with the job's JWT variables as before. `tests/dynamic_login_proof.robot` checks it,
read-only: the login, a QueryRecords, NavigateToApp, and the browser on the same org as the API.

It runs in CRT job 210329, apart from the quality-gate job on `main` (SDO QA - US-0000032 negative amount).
Earlier probes on this branch: 28785fe (the loginUrl token answers SOQL), 1bfbd47 (QForce takes the token).
