*** Settings ***
Documentation       Shared setup for the SDO Agentia CRT tests.
...                 Run by Copado CI/CD (a user story test or a quality gate): Copado passes ${loginUrl}, a one-click
...                 login to the destination environment. Run on its own in CRT: no ${loginUrl}, so the UI login uses
...                 the job's JWT variables (client_id / username / private_key, set in CRT, never in this repo).
...                 Under CI/CD the database checks run on the same session as the browser, with no JWT.
Library             QForce
Library             QWeb
Library             String
Library             DateTime
Library             Collections
Library             FakerLibrary

*** Variables ***
${loginUrl}         ${EMPTY}
# Never declare the JWT variables here: CRT supplies them, and declared in this file they break Live Testing.
# ${client_id}        NOT_SET
# ${username}         NOT_SET
# ${private_key}      NOT_SET
# Optional, and only for an org that refuses both test.salesforce.com and login.salesforce.com: its My Domain URL.
# Not named login_url: Robot ignores case and underscores, so that name IS ${loginUrl}.
${jwt_url}          ${EMPTY}
${TEST_ACCOUNT_ID}  ${EMPTY}
#
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

CICD And CRT Dynamic Login
    [Documentation]    One login for a CRT job run on its own and run by a Copado CI/CD quality gate.
    ...                Under CI/CD the browser opens Copado's loginUrl, and QForce's API keywords (records, SOQL,
    ...                Execute Apex) get that same session, so both work in whichever environment CI/CD targets,
    ...                with no JWT. Run on its own in CRT: JWT at test.salesforce.com, then login.salesforce.com,
    ...                or at jwt_url when set. Sets INSTANCE (the org's URL) and API (True when QForce's API keywords
    ...                can run). Never call QForce's Revoke under CI/CD: it would end Copado's session for every
    ...                suite after it.
    # the loginUrl carries a live session, and the JWT variables are credentials: logging stays off while they are read
    ${level}=    Set Log Level    NONE
    TRY
        ${host}=    Evaluate    (re.findall(r'https://[^/?]+', $loginUrl) or [''])[0]    re
        ${cicd_session}=    Evaluate    'sid=' in $loginUrl
        ${client}=    Get Variable Value    ${client_id}    NOT_SET
        ${jwt}=    Evaluate    $client != 'NOT_SET'
        IF    ${cicd_session}    GoTo    ${loginUrl}
    FINALLY
        Set Log Level    ${level}
    END
    IF    ${cicd_session}
        ${api}=    CICD Session Into QForce
        IF    not ${api} and ${jwt}
            ${api}    ${reason}=    JWT Sign In    custom_url=${host}
        END
        IF    not ${api}
            Log    QForce cannot use the CI/CD session and the job's JWT variables do not sign in at ${host}: API checks are off.    level=WARN    console=True
        END
        Set Suite Variable    ${INSTANCE}    ${host}
        Set Suite Variable    ${API}    ${api}
        Log    Logged in through the Copado CI/CD loginUrl: ${INSTANCE} (API: ${API})    console=True
        RETURN
    END
    IF    not ${jwt}
        Fail    No way to log in: no CI/CD session in the loginUrl and no client_id/username/private_key variables.
    END
    IF    $host
        # a loginUrl without a session: a URL set on the job, or a CI/CD credential that has expired
        Log    The loginUrl carries no session: signing in with JWT at ${host}.    level=WARN    console=True
        ${ok}    ${reason}=    JWT Sign In    custom_url=${host}
    ELSE IF    $jwt_url
        ${custom}=    Evaluate    $jwt_url.strip().rstrip('/')
        ${ok}    ${reason}=    JWT Sign In    custom_url=${custom}
    ELSE
        ${ok}    ${reason}=    JWT Sign In    sandbox=${True}
        IF    not ${ok}
            ${ok}    ${reason}=    JWT Sign In
        END
    END
    IF    not ${ok}
        Fail    The job's JWT variables did not sign in: ${reason}
    END
    JwtLogin
    ${instance}=    GetInstanceUrl
    Set Suite Variable    ${INSTANCE}    ${instance}
    Set Suite Variable    ${API}    ${True}
    Log    Logged in with JWT: ${INSTANCE}    console=True

CICD Session Into QForce
    [Documentation]    Gives QForce's API keywords the session in the CI/CD loginUrl, then checks QForce answers from
    ...                that session's org. Returns True if it does. Otherwise it clears the session out of QForce and
    ...                returns False, so QForce never answers from another org.
    ...                Python on purpose: QForce has no keyword that takes a token, so this sets the three values its
    ...                API keywords read (_token, instance_url and version_url in QForce.keywords.rest_api; true in
    ...                QForce 2025.40 and 2026.39). The org check catches a QForce release that changes them.
    ${level}=    Set Log Level    NONE
    TRY
        ${rest}=    Evaluate    importlib.import_module('QForce.keywords.rest_api')    importlib
        ${token}=    Evaluate    urllib.parse.unquote(re.search(r'[?&]sid=([^&]+)', $loginUrl).group(1))    re, urllib.parse
        ${host}=    Evaluate    re.search(r'https://[^/?]+', $loginUrl).group(0)    re
        Evaluate    setattr($rest, '_token', $token)
        Evaluate    setattr($rest, 'instance_url', $host)
        Evaluate    setattr($rest, 'version_url', $rest._get_version_url($host, 30))
        # a Salesforce session starts with its org's 15-character Id
        ${session_org}=    Evaluate    $token[:15]
    EXCEPT
        Run Keyword And Ignore Error    Evaluate    setattr($rest, '_token', None)
        Set Log Level    ${level}
        Log    QForce did not take the CI/CD session: check this keyword against the QForce version.    level=WARN    console=True
        RETURN    ${False}
    FINALLY
        Set Log Level    ${level}
    END
    ${status}    ${org}=    Run Keyword And Ignore Error    QueryRecords    SELECT Id FROM Organization
    IF    $status == 'PASS'
        IF    $org['records'][0]['Id'][:15] == $session_org    RETURN    ${True}
    END
    Evaluate    setattr($rest, '_token', None)
    Log    QForce did not answer from the CI/CD session's org, so the session is cleared out of QForce.    level=WARN    console=True
    RETURN    ${False}

JWT Sign In
    [Documentation]    JWTAuthenticate with the job's JWT variables, with logging off so the private key never reaches
    ...                the log (at TRACE level Robot logs every keyword's arguments). Name where to sign in:
    ...                custom_url=..., or sandbox=True, or nothing for login.salesforce.com. Returns True or False, and
    ...                Salesforce's reason when it is False.
    [Arguments]    &{where}
    ${level}=    Set Log Level    NONE
    TRY
        ${status}    ${reason}=    Run Keyword And Ignore Error    JWTAuthenticate    ${client_id}    ${username}    ${private_key}    &{where}
    FINALLY
        Set Log Level    ${level}
    END
    # JWTAuthenticate returns the session it opened: hand back Salesforce's reason only when it failed
    RETURN    ${{ $status == 'PASS' }}    ${{ '' if $status == 'PASS' else $reason }}

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
