*** Settings ***
Documentation       CICD And CRT Dynamic Login, written in Robot Framework: one login for a CRT job run on its own
...                 and run by a Copado CI/CD quality gate. A suite imports this file OR resources/CicdDynamicLogin.py
...                 (the same login written in Python), never both: they define the same keyword.
...                 Never declare client_id, username or private_key in a file: CRT supplies them, and declared in a
...                 file they break Live Testing.
Library             QForce
Library             QWeb

*** Variables ***
${loginUrl}         ${EMPTY}
# Optional, and only for an org that refuses both test.salesforce.com and login.salesforce.com: its My Domain URL.
# Not named login_url: Robot ignores case and underscores, so that name IS ${loginUrl}.
${jwt_url}          ${EMPTY}

*** Keywords ***
CICD And CRT Dynamic Login
    [Documentation]    Signs the browser AND QForce's API keywords (QueryRecords, CreateRecord, ExecuteApex,
    ...                JwtLoginAs, GoToRecord...) in to one org, however the job was started.
    ...                Under Copado CI/CD, Copado's loginUrl is split in two: the browser opens it, and the session in it
    ...                goes to QForce's API keywords. No JWT is needed, and the org is whichever one CI/CD targets.
    ...                Run on its own in CRT: JWT with the job's client_id / username / private_key, at
    ...                test.salesforce.com, then login.salesforce.com, or at jwt_url when set.
    ...                Afterwards, for the whole suite: INSTANCE is the org's address, API is True when QForce's API
    ...                keywords can run, and login_url is the org's address, so GoToRecord takes a bare record Id.
    ...                Called again in the same suite, it signs the browser back in as the same user (after JwtLoginAs).
    ...                Never call QForce's Revoke under CI/CD: it would end Copado's session for every suite after it.
    ${signed_in}=    Get Variable Value    ${SIGNED_IN_WITH}    ${EMPTY}
    IF    $signed_in
        Sign The Browser Back In
        RETURN
    END
    # the loginUrl may carry a live session and the JWT variables are credentials: logging stays off while they are read
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
        Signed In    cicd    ${host}    ${api}
        RETURN
    END
    IF    not ${jwt}
        Fail    No way to log in: no CI/CD session in the loginUrl and no client_id/username/private_key variables.
    END
    IF    $host
        # a loginUrl without a session: an address set on the job, or a CI/CD credential that has expired
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
    Signed In    jwt    ${instance}    ${True}

Signed In
    [Documentation]    Records how the suite signed in, and sets INSTANCE, API and login_url for the whole suite.
    [Arguments]    ${how}    ${instance}    ${api}
    Set Suite Variable    ${SIGNED_IN_WITH}    ${how}
    Set Suite Variable    ${INSTANCE}    ${instance}
    Set Suite Variable    ${API}    ${api}
    Set Login Url To The Instance
    IF    $how == 'cicd'
        Log    Logged in through the Copado CI/CD loginUrl: ${INSTANCE} (API: ${API})    console=True
    ELSE
        Log    Logged in with JWT: ${INSTANCE}    console=True
    END

Set Login Url To The Instance
    [Documentation]    GoToRecord opens login_url + "/" + the record Id. Robot ignores case and underscores, so login_url
    ...                IS Copado's loginUrl, and three values can reach it:
    ...                - empty (run on its own in CRT): it becomes the org's address;
    ...                - Copado's link with a session (CI/CD): it becomes the link's host, the org's address. The session
    ...                went to QForce's API; inside an address, GoToRecord would break and its GoTo would log it;
    ...                - an org address set on the job: kept. A generic login page (login. or test.salesforce.com) is
    ...                not an org, so it is replaced too.
    ...                Set for the suite, so every later test has it, even one that does not log in itself.
    ${level}=    Set Log Level    NONE
    TRY
        ${keep}=    Evaluate    bool(re.fullmatch(r'https://(?!(login|test)\\.salesforce\\.com/?$)[^/?#\\s]+/?', ($login_url or '').strip()))    re
    FINALLY
        Set Log Level    ${level}
    END
    IF    not ${keep}    Set Suite Variable    $login_url    ${INSTANCE}

Sign The Browser Back In
    [Documentation]    The suite has signed in already: puts the browser back as the signed-in user, after a JwtLoginAs
    ...                or a browser restart. JWT: JwtLogin. CI/CD: the frontdoor link is rebuilt from the session QForce
    ...                holds, with logging off.
    IF    $SIGNED_IN_WITH == 'jwt'
        JwtLogin
        RETURN
    END
    ${level}=    Set Log Level    NONE
    TRY
        ${token}=    Evaluate    importlib.import_module('QForce.keywords.rest_api')._token or ''    importlib
        ${link}=    Evaluate    $INSTANCE + '/secur/frontdoor.jsp?sid=' + urllib.parse.quote($token)    urllib.parse
        IF    $token    GoTo    ${link}
    FINALLY
        Set Log Level    ${level}
    END
    IF    not $token
        Log    QForce holds no session to sign the browser back in with: the browser stays as it is.    level=WARN    console=True
    END

CICD Session Into QForce
    [Documentation]    Gives QForce's API keywords the session in the CI/CD loginUrl, then checks QForce answers from
    ...                that session's org. Returns True if it does. Otherwise it clears the session out of QForce and
    ...                returns False, so QForce never answers from another org.
    ...                Python on purpose: QForce has no keyword that takes a session, so this sets the three values its
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
