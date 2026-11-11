*** Settings ***
Documentation     CI/CD session hand-off to QForce: under Copado CI/CD, QForce's API keywords (records, SOQL,
...               Execute Apex) run on the session Copado passes in the loginUrl variable, with no JWT.
Library           QForce
Library           String

*** Variables ***
${loginUrl}       ${EMPTY}

*** Keywords ***
CICD Token Into QForce
    [Documentation]    Hands the session in the CI/CD loginUrl to QForce, then checks QForce answers from that
    ...                session's org. Sets the suite variables QFORCE_ON_CICD_TOKEN (True or False) and CICD_HOST.
    # logging off before the loginUrl is first read: at TRACE level every keyword's arguments are logged
    ${level}=    Set Log Level    NONE
    ${has_sid}=    Evaluate    'sid=' in $loginUrl
    IF    ${has_sid}
        ${host}=    Get Regexp Matches    ${loginUrl}    (https://[^/?]+)    1
        ${sid}=    Get Regexp Matches    ${loginUrl}    [?&]sid=([^&]+)    1
        # QForce has no keyword that takes a token, so set the three values its API keywords read
        # (QForce.keywords.rest_api: _token, instance_url, version_url; read from QForce 2025.40).
        # They are private to QForce: the org check below catches a QForce release that changes them.
        ${rest}=    Evaluate    importlib.import_module('QForce.keywords.rest_api')    importlib
        Evaluate    setattr($rest, '_token', urllib.parse.unquote($sid[0]))    urllib.parse
        Evaluate    setattr($rest, 'instance_url', $host[0])
        Evaluate    setattr($rest, 'version_url', $rest._get_version_url($host[0], 30))
        # a Salesforce session starts with its org's 15-character Id
        ${token_org}=    Evaluate    urllib.parse.unquote($sid[0])[:15]    urllib.parse
    END
    Set Log Level    ${level}
    IF    not ${has_sid}
        Set Suite Variable    ${QFORCE_ON_CICD_TOKEN}    ${False}
        Log    No CI/CD loginUrl with a session in this run: QForce API keywords need JwtAuthenticate    console=True
        RETURN
    END
    Set Suite Variable    ${CICD_HOST}    ${host}[0]
    ${org}=    QueryRecords    SELECT Id FROM Organization
    ${org_id}=    Set Variable    ${org}[records][0][Id]
    ${org15}=    Get Substring    ${org_id}    0    15
    Should Be Equal    ${org15}    ${token_org}    QForce answered from another org than the CI/CD session's
    Set Suite Variable    ${QFORCE_ON_CICD_TOKEN}    ${True}
    Log    QForce API keywords run on the CI/CD session: ${CICD_HOST}, org ${org_id}    console=True

Organization Name From The Resource File
    [Documentation]    A QForce read called from this resource file, after the hand-off.
    ${org}=    QueryRecords    SELECT Id FROM Organization
    ${record}=    Get Record    Organization    ${org}[records][0][Id]
    RETURN    ${record}[Name]
