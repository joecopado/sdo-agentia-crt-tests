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

*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser    about:blank    chrome
    SetConfig    LineBreak    ${EMPTY}
    SetConfig    DefaultTimeout    20s

End Suite
    Close All Browsers

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
