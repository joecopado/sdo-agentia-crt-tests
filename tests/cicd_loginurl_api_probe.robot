*** Settings ***
Documentation     Does the session token Copado CI/CD puts in the loginUrl variable work for the Salesforce REST API (SOQL)?
...               Started from Copado CI/CD: lists every variable name in the run, then makes two read-only REST
...               calls with the token. Started directly in CRT: no loginUrl arrives, so only the list runs.
...               Logging is switched off while the token and the variable values are handled, so neither the
...               loginUrl nor any secret reaches the log.
Library           Collections
Library           String
Library           RequestsLibrary

*** Variables ***
${loginUrl}       ${EMPTY}
${API_VERSION}    v62.0

*** Test Cases ***
Variables In This Run
    # names and value lengths only: the values include the loginUrl token and any job secrets
    ${level}=    Set Log Level    NONE
    ${vars}=    Get Variables    no_decoration=True
    ${names}=    Get Dictionary Keys    ${vars}
    ${rows}=    Create List
    FOR    ${name}    IN    @{names}
        ${text}=    Convert To String    ${vars}[${name}]
        ${size}=    Get Length    ${text}
        Append To List    ${rows}    ${name} (${size})
    END
    Set Log Level    ${level}
    ${count}=    Get Length    ${rows}
    Log    ${count} variables: ${rows}    console=True

loginUrl Token Answers SOQL
    # logging goes off before the loginUrl is first read: at TRACE level every keyword's arguments are logged
    ${level}=    Set Log Level    NONE
    ${size}=    Get Length    ${loginUrl}
    ${host}=    Get Regexp Matches    ${loginUrl}    (https://[^/?]+)    1
    ${has_sid}=    Evaluate    'sid=' in $loginUrl
    Set Log Level    ${level}
    Skip If    ${size} == 0    No loginUrl in this run (started directly in CRT): COULD-NOT-CHECK
    Log    loginUrl: ${size} characters, host ${host}[0]    console=True
    Skip If    not ${has_sid}    The loginUrl carries no sid (the CI/CD credential did not mint one): COULD-NOT-CHECK
    ${level}=    Set Log Level    NONE
    ${sid}=    Get Regexp Matches    ${loginUrl}    [?&]sid=([^&]+)    1
    # the sid can arrive URL-encoded (! as %21); the API needs it decoded
    ${token}=    Evaluate    urllib.parse.unquote($sid[0])    urllib.parse
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}
    Create Session    target    ${host}[0]    headers=${headers}
    ${params}=    Create Dictionary    q=SELECT Id, Name, IsSandbox FROM Organization
    ${org}=    GET On Session    target    /services/data/${API_VERSION}/query    params=${params}    expected_status=any
    ${me}=    GET On Session    target    /services/data/${API_VERSION}/chatter/users/me    expected_status=any
    Set Log Level    ${level}
    Log    SOQL through the REST API: HTTP ${org.status_code}    console=True
    Log    chatter/users/me: HTTP ${me.status_code}    console=True
    IF    ${org.status_code} == 200
        ${record}=    Set Variable    ${org.json()}[records][0]
        Log    Organization ${record}[Id] (${record}[Name], sandbox: ${record}[IsSandbox])    console=True
    ELSE
        Log    The REST API refused the token: ${org.text}    console=True
    END
    IF    ${me.status_code} == 200
        Log    Signed in as ${me.json()}[name] (${me.json()}[id])    console=True
    END
    Should Be Equal As Integers    ${org.status_code}    200    The loginUrl token did not answer SOQL
