# CI/CD loginUrl API probe

A separate branch for one question: does the session token that Copado CI/CD puts in `${loginUrl}` work for
the Salesforce REST API (SOQL), or only for the browser?

`tests/cicd_loginurl_api_probe.robot` lists every variable name in the run (names and value lengths, never
values), then, when a `loginUrl` arrives, makes two read-only REST calls with its token:
`SELECT Id, Name, IsSandbox FROM Organization` and `chatter/users/me`. Logging is off while the token is
handled. It never writes to any org.

It runs in its own CRT job, so the quality-gate job on `main` (SDO QA - US-0000032 negative amount) is untouched.
