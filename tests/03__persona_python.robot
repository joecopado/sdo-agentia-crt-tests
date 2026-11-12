*** Settings ***
Documentation       One test under a specific user, run on its own in CRT and by Copado CI/CD. The login is the Python
...                 version (resources/CicdDynamicLogin.py); every test step is a stock QForce or QWeb keyword.
...                 API and UI keywords work on one org, and the persona's change is read back through the API.
Resource            ../resources/common.robot
Library             ../resources/CicdDynamicLogin.py
Suite Setup         Setup Browser
Suite Teardown      Run Keywords    Delete Test Record    Account    ${ACCOUNT_ID}    AND    End Suite

*** Variables ***
# a user copied from production, so the same full name exists in every sandbox (usernames do not carry over)
${PERSONA}          Cindy Central
${ACCOUNT_ID}       ${EMPTY}

*** Test Cases ***
The Signed-In User Works Through The API And The UI
    CICD And CRT Dynamic Login
    # login_url is the org's address: never empty, and never Copado's link with its session
    Should Be True    $login_url == $INSTANCE    msg=login_url is not the org's address.
    LogScreenshot
    # API: the persona's user Id, then an Account the persona owns
    ${persona}=    QueryRecords    SELECT Id FROM User WHERE Name = '${PERSONA}' AND IsActive = true
    Should Be Equal As Integers    ${persona}[totalSize]    1    msg=No single active user named ${PERSONA} in this org.
    ${company}=    FakerLibrary.Company
    ${name}=    Set Variable    ${company} (persona demo)
    ${id}=    CreateRecord    Account    Name=${name}    OwnerId=${persona}[records][0][Id]
    Set Suite Variable    ${ACCOUNT_ID}    ${id}
    # UI: GoToRecord takes the bare Id
    GoToRecord    ${id}
    VerifyText    ${name}
    LogScreenshot
    # API write, UI read
    UpdateRecord    Account    ${id}    Website=www.persona-demo.example.com
    RefreshPage
    VerifyText    www.persona-demo.example.com
    LogScreenshot
    # Apex through the same session, read back with SOQL
    # an = in a keyword argument reads as a named argument: \= keeps it part of the Apex
    ExecuteApex    update new Account(Id \= '${id}', Description \= 'Written by Apex');
    ${account}=    QueryRecords    SELECT Description FROM Account WHERE Id = '${id}'
    Should Be Equal    ${account}[records][0][Description]    Written by Apex

The Persona Edits Their Account In The UI
    # no login step: the suite's login still holds, so GoToRecord and the API keep working
    JwtLoginAs    ${PERSONA}
    VerifyText    Log out as ${PERSONA}    timeout=30
    LogScreenshot
    GoToRecord    ${ACCOUNT_ID}
    VerifyText    persona demo
    LogScreenshot
    GoTo    ${INSTANCE}/lightning/r/Account/${ACCOUNT_ID}/edit
    UseModal    On
    TypeText    Phone    5550101234
    ClickText    Save    partial_match=False
    UseModal    Off
    VerifyText    Log out as ${PERSONA}
    LogScreenshot
    # the API is still the signed-in user: it reads the change back, and who made it
    ${account}=    QueryRecords    SELECT Phone, LastModifiedBy.Name FROM Account WHERE Id = '${ACCOUNT_ID}'
    Should Be Equal    ${account}[records][0][LastModifiedBy][Name]    ${PERSONA}
    Should Contain    ${account}[records][0][Phone]    010
