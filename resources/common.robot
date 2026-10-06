*** Settings ***
Documentation       Shared setup for the SDO Agentia CRT tests.
...                 Run by Copado CI/CD (a user story test or a quality gate): Copado passes ${loginUrl}, a one-click
...                 login to the destination environment. Run on its own in CRT: no ${loginUrl}, so the UI login uses
...                 the job's JWT variables. The JWT variables (client_id / username / private_key, set in CRT, never
...                 in this repo) also open an API session whenever they are present, for database checks.
Library             QForce
Library             QWeb
Library             String
Library             DateTime
Library             Collections
Library             FakerLibrary

*** Variables ***
${loginUrl}         ${EMPTY}
${client_id}        NOT_SET
${username}         NOT_SET
${private_key}      NOT_SET
${TEST_ACCOUNT_ID}  ${EMPTY}

*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser    about:blank    chrome
    SetConfig    LineBreak    ${EMPTY}
    SetConfig    DefaultTimeout    20s

End Suite
    Close All Browsers

Delete Test Record
    [Documentation]    Teardown: delete one record this test created through the API, if it got that far.
    [Arguments]    ${sobject}    ${record_id}
    IF    '${record_id}' != '${EMPTY}'
        Delete Record    ${sobject}    ${record_id}
        Log    Teardown: deleted ${sobject} ${record_id}    console=True
    END

Login To QA
    [Documentation]    API session from the JWT variables when present; UI login from Copado's loginUrl, else JWT.
    ...                Sets ${INSTANCE} and ${API} (True when SOQL checks can run).
    ${api}=    Evaluate    '${client_id}' != 'NOT_SET'
    IF    ${api}
        JWTAuthenticate    ${client_id}    ${username}    ${private_key}    sandbox=true
    END
    Set Suite Variable    ${API}    ${api}
    IF    '${loginUrl}' != '${EMPTY}'
        ${host}=    Get Regexp Matches    ${loginUrl}    (https://[^/?]+)    1
        GoTo    ${loginUrl}
        Set Suite Variable    ${INSTANCE}    ${host}[0]
        Log    Logged in through the Copado CI/CD loginUrl: ${INSTANCE}    console=True
    ELSE IF    ${api}
        JwtLogin
        ${instance}=    GetInstanceUrl
        Set Suite Variable    ${INSTANCE}    ${instance}
        Log    Logged in with JWT: ${INSTANCE}    console=True
    ELSE
        Fail    No way to log in: Copado passed no loginUrl and the job has no client_id/username/private_key variables.
    END

Create Test Account
    [Documentation]    Creates an Account through the API for this test. Delete Test Account removes it in teardown.
    [Arguments]    ${name}
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key) for its API steps.
    ${id}=    Create Record    Account    Name=${name}
    Set Test Variable    ${TEST_ACCOUNT_ID}    ${id}

Delete Test Account
    [Documentation]    Teardown: deletes the Account that Create Test Account made, if the test got that far.
    Delete Test Record    Account    ${TEST_ACCOUNT_ID}

Open New Record Form
    [Documentation]    Opens an object's New form by its URL. Name a record type to open the form as that type; leave it
    ...                out to open the object's default form (an object with several record types available to the user
    ...                may first show Salesforce's record type choice).
    [Arguments]    ${object}    ${record_type}=${EMPTY}
    IF    '${record_type}' == '${EMPTY}'
        GoTo    ${INSTANCE}/lightning/o/${object}/new
    ELSE
        ${rt}=    QueryRecords    SELECT Id FROM RecordType WHERE SobjectType = '${object}' AND Name = '${record_type}' AND IsActive = true
        Should Be True    ${rt}[totalSize] == 1    msg=No active record type named '${record_type}' on ${object}.
        GoTo    ${INSTANCE}/lightning/o/${object}/new?recordTypeId\=${rt}[records][0][Id]
    END

Test Account Should Have No Opportunities
    [Documentation]    Database check: no Opportunity was saved on the Account this test created.
    ${saved}=    QueryRecords    SELECT Id FROM Opportunity WHERE AccountId = '${TEST_ACCOUNT_ID}'
    Should Be Equal As Integers    ${saved}[totalSize]    0    msg=An Opportunity was saved on the test Account.
