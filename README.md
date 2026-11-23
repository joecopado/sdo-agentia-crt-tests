# SDO Agentia CRT tests: the SDO QA quality gate (job 204886)

One login for a CRT job that runs on its own in CRT AND as a Copado CI/CD quality gate, in two versions that do the
same thing (the Robot Framework one is what to share; the Python one is for our development team), and one test under a specific user that proves it.

| File | What it is |
|---|---|
| `resources/common.robot` | the browser setup and record cleanup every suite shares |
| `resources/login_robot.robot` | `CICD And CRT Dynamic Login`, written in Robot Framework |
| `resources/CicdDynamicLogin.py` | the same keyword written in Python, for teams that write keywords in Python |
| `tests/create_lead.robot`, `account_becomes_customer.robot`, `us_0000032_negative_amount.robot` | the quality-gate tests; each imports the login |
| `tests/02__persona_robot.robot` | the persona test with the Robot Framework login |

**The login.** Under Copado CI/CD, Copado passes one variable, `${loginUrl}`: a frontdoor link with a live session in
it. The login splits it in two: the browser opens the link, and the session goes to QForce's API keywords, so
`QueryRecords`, `CreateRecord`, `UpdateRecord`, `ExecuteApex`, `JwtLoginAs` and `GoToRecord` all work in whatever
environment CI/CD targets, with no JWT. Run on its own in CRT, it signs in with the job's JWT variables (`client_id`,
`username`, `private_key`: set in CRT, never in this repo). Either way it sets `${INSTANCE}`, `${API}` and `login_url`
for the whole suite.

**`login_url`.** Robot ignores case and underscores, so `login_url` IS Copado's `loginUrl`. GoToRecord opens
`login_url/<record Id>`. Empty (run on its own): it becomes the org's address. Copado's link with its session (CI/CD):
it becomes the link's host, the org's address; the session went to QForce. An org address set on the job: kept.

**The persona test.** Signed in as the job's user: a Contact created through the API and owned by the persona, opened with
`GoToRecord`, changed through the API and read in the UI, changed by Apex and read back with SOQL. Then `JwtLoginAs` by
the persona's FULL NAME (a sandbox keeps production users' full names; usernames get the sandbox name appended), the
persona edits the Contact's Title in the UI, and the API reads back the new Title and that the persona made the change.
Screenshots go to the log with `LogScreenshot`. The Contact is deleted in the suite teardown. The persona (Cindy Central,
SDO-Sales) may read, create and edit Contacts in SDO dev1 and QA, and has no access to Accounts: the first run used an
Account, and her page said "This page isn't available" -- the persona's real restriction, while the admin could open it.


**Canonical copy for other teams:** github.com/joecopado/crt-cicd-common (Robot Framework login only). The probes (stock QForce under CI/CD, Dynamic Expressions, the Python persona test) stay on branch `cicd-crt-persona-demo`.
