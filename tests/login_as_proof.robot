*** Settings ***
Documentation       Proof, read-only: after CICD And CRT Dynamic Login, QForce's JwtLoginAs opens the browser as another
...                 user, named by full name. From Copado CI/CD (SDO dev1) it runs on the CI/CD session; run on its own
...                 in CRT (SDO QA), on JWT. The same full name is used in both environments.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Variables ***
# an SDO-Sales user copied from production, so the same full name exists in every environment
${PERSONA}          Cindy Central

*** Test Cases ***
JwtLoginAs Opens The Browser As A User Named By Full Name
    CICD And CRT Dynamic Login
    Log    Logged in to ${INSTANCE} (API: ${API}); now Login As ${PERSONA}    console=True
    JwtLoginAs    ${PERSONA}
    VerifyText    Log out as ${PERSONA}    timeout=30
    Log    The browser is now ${PERSONA}: "Log out as ${PERSONA}" is on the page    console=True
    # QForce's API stays the signed-in admin, so SOQL still runs after the Login As
    ${user}=    QueryRecords    SELECT Profile.Name FROM User WHERE Name = '${PERSONA}' AND IsActive = true
    Log    ${PERSONA}'s profile, read through the API after the Login As: ${user}[records][0][Profile][Name]    console=True
