*** Settings ***
Documentation       One test under a specific user, run on its own in CRT and by Copado CI/CD. The login is the Python
...                 version (resources/CicdDynamicLogin.py); every test step is a stock QForce or QWeb keyword.
...                 API and UI keywords work on one org, and the persona's edit is read back through the API.
Resource            ../resources/common.robot
Library             ../resources/CicdDynamicLogin.py
Suite Setup         Setup Browser
Suite Teardown      Run Keywords    Delete Test Record    Contact    ${CONTACT_ID}    AND    End Suite

*** Variables ***
# a user copied from production, so the same full name exists in every sandbox (usernames do not carry over);
# in SDO dev1 and QA alike Cindy may read, create and edit Contacts, and has no access to Accounts
${PERSONA}          Cindy Central
${CONTACT_ID}       ${EMPTY}
${CONTACT_NAME}     ${EMPTY}

*** Test Cases ***
The Signed-In User Works Through The API And The UI
    CICD And CRT Dynamic Login
    # login_url is the org's address: never empty, and never Copado's link with its session
    Should Be True    $login_url == $INSTANCE    msg=login_url is not the org's address.
    LogScreenshot
    # API: the persona's user Id, then a Contact the persona owns
    ${persona}=    QueryRecords    SELECT Id FROM User WHERE Name = '${PERSONA}' AND IsActive = true
    Should Be Equal As Integers    ${persona}[totalSize]    1    msg=No single active user named ${PERSONA} in this org.
    ${first}=    FakerLibrary.First Name
    ${last}=    FakerLibrary.Last Name
    ${id}=    CreateRecord    Contact    FirstName=${first}    LastName=${last}    OwnerId=${persona}[records][0][Id]
    Set Suite Variable    ${CONTACT_ID}    ${id}
    Set Suite Variable    ${CONTACT_NAME}    ${first} ${last}
    # UI: GoToRecord takes the bare Id
    GoToRecord    ${id}
    VerifyText    ${CONTACT_NAME}
    LogScreenshot
    # API write, UI read
    UpdateRecord    Contact    ${id}    Title=Set by the API
    RefreshPage
    VerifyText    Set by the API
    LogScreenshot
    # Apex through the same session, read back with SOQL
    # an = in a keyword argument reads as a named argument: \= keeps it part of the Apex
    ExecuteApex    update new Contact(Id \= '${id}', Description \= 'Written by Apex');
    ${contact}=    QueryRecords    SELECT Description FROM Contact WHERE Id = '${id}'
    Should Be Equal    ${contact}[records][0][Description]    Written by Apex

The Persona Edits Their Contact In The UI
    # no login step: the suite's login still holds, so GoToRecord and the API keep working
    JwtLoginAs    ${PERSONA}
    VerifyText    Log out as ${PERSONA}    timeout=30
    LogScreenshot
    GoToRecord    ${CONTACT_ID}
    VerifyText    ${CONTACT_NAME}
    LogScreenshot
    GoTo    ${INSTANCE}/lightning/r/Contact/${CONTACT_ID}/edit
    UseModal    On
    TypeText    Title    Edited by ${PERSONA}
    ClickText    Save    partial_match=False
    UseModal    Off
    # a Save from the edit URL closes the modal onto the page behind it (her Home): open the record to see the change
    GoToRecord    ${CONTACT_ID}
    VerifyText    Edited by ${PERSONA}
    LogScreenshot
    # the API is still the signed-in user: it reads the change back, and who made it
    ${contact}=    QueryRecords    SELECT Title, LastModifiedBy.Name FROM Contact WHERE Id = '${CONTACT_ID}'
    Should Be Equal    ${contact}[records][0][Title]    Edited by ${PERSONA}
    Should Be Equal    ${contact}[records][0][LastModifiedBy][Name]    ${PERSONA}
