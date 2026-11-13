*** Settings ***
Documentation       Keywords for tests/05__custom_url_proof.robot: one JWT sign-in with one org's credentials at one
...                 place, and the read-backs of which org the API and the browser are on.
Library             QForce
Library             QWeb

*** Keywords ***
Sign In With
    [Documentation]    JWTAuthenticate with one org's credentials at one place. Who: qa (the robot's client_id, username
    ...                and private_key) or prod (the job's prod_client_id, prod_username and prod_private_key). Where:
    ...                custom_url set to an address, sandbox set to True (test.salesforce.com), or nothing
    ...                (login.salesforce.com). Logging is off while the credentials are read and used. Returns True or
    ...                False, and on False Salesforce's reason, with anything shaped like a key, a token or a session
    ...                taken out.
    [Arguments]    ${who}    &{where}
    ${level}=    Set Log Level    NONE
    TRY
        IF    $who == 'prod'
            ${id}=    Get Variable Value    ${prod_client_id}    NOT_SET
            ${user}=    Get Variable Value    ${prod_username}    NOT_SET
            ${key}=    Get Variable Value    ${prod_private_key}    NOT_SET
        ELSE
            ${id}=    Get Variable Value    ${client_id}    NOT_SET
            ${user}=    Get Variable Value    ${username}    NOT_SET
            ${key}=    Get Variable Value    ${private_key}    NOT_SET
        END
        ${missing}=    Evaluate    'NOT_SET' in ($id, $user, $key)
        IF    not ${missing}
            ${status}    ${reason}=    Run Keyword And Ignore Error    JWTAuthenticate    ${id}    ${user}    ${key}    &{where}
            ${reason}=    Evaluate    '' if $status == 'PASS' else re.sub(r'00D\\w{12,15}!\\S+', '<session>', re.sub(r'eyJ[\\w-]+\\.[\\w-]+\\.[\\w-]*', '<jwt>', re.sub(r'-----BEGIN[\\s\\S]*?-----END[^\\n]*', '<key>', str($reason))))[:400]    re
        END
    FINALLY
        Set Log Level    ${level}
    END
    IF    ${missing}    Fail    The job has no ${who} credentials: client_id, username and private_key (prod_ for prod).
    RETURN    ${{ $status == 'PASS' }}    ${reason}

Signed In To
    [Documentation]    Reads which org QForce's API keywords now answer from: its address, name and Id, and whether it is
    ...                a sandbox. Fails when the address or the sandbox flag is not the one expected.
    [Arguments]    ${address}    ${sandbox}
    ${instance}=    GetInstanceUrl
    ${org}=    QueryRecords    SELECT Id, Name, IsSandbox, OrganizationType FROM Organization
    ${row}=    Set Variable    ${org}[records][0]
    Log    QForce answers from ${row}[Name] (${row}[Id], ${row}[OrganizationType], sandbox ${row}[IsSandbox]) at ${instance}    console=True
    Should Be Equal    ${{ $instance.rstrip('/').lower() }}    ${{ $address.rstrip('/').lower() }}    msg=QForce answers from ${instance}, not ${address}.
    Should Be Equal    ${row}[IsSandbox]    ${sandbox}    msg=IsSandbox is ${row}[IsSandbox], expected ${sandbox}.

Browser Should Be On
    [Documentation]    The browser's page is on the org at this address. Only the host is logged: right after JwtLogin
    ...                the page can still be Salesforce's one-time sign-in link.
    [Arguments]    ${address}
    ${level}=    Set Log Level    NONE
    TRY
        ${page}=    GetUrl
        ${host}=    Evaluate    $page.split('/')[2].lower() if '//' in $page else $page.lower()
        ${org_name}=    Evaluate    $address.split('//')[-1].split('.')[0].lower()
        ${on_it}=    Evaluate    $host.startswith($org_name + '.')
    FINALLY
        Set Log Level    ${level}
    END
    Log    The browser is on ${host}    console=True
    Should Be True    ${on_it}    msg=The browser is on ${host}, not the org at ${address}.
