*** Settings ***
Documentation       Proof of CICD And CRT Dynamic Login, read-only. Started from Copado CI/CD (US-0000039, SDO dev1),
...                 the browser and QForce's API keywords should both use the CI/CD session; run on its own in CRT,
...                 the job's JWT variables (SDO QA). After the login, GoToRecord should open a record from its Id
...                 alone, and the second test's login should still find Copado's link.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
The Browser And QForce Are Signed In To The Same Org
    CICD And CRT Dynamic Login
    Should Be True    ${API}    msg=QForce's API keywords cannot run after the login
    ${org}=    QueryRecords    SELECT Id, Name, IsSandbox FROM Organization
    Log    QueryRecords answered from ${org}[records][0][Id] (${org}[records][0][Name])    console=True
    # NavigateToApp needs QForce's API session as well as the browser
    NavigateToApp    LightningSales
    # the browser's address is read with logging off: until the page moves on, it can still carry the session
    ${level}=    Set Log Level    NONE
    TRY
        ${url}=    GetUrl
        ${browser_org}=    Evaluate    $url.split('//')[1].split('.')[0]
    FINALLY
        Set Log Level    ${level}
    END
    ${instance_org}=    Evaluate    $INSTANCE.split('//')[1].split('.')[0]
    Log    The browser is on ${browser_org}, the login's instance is ${instance_org}    console=True
    Should Be Equal    ${browser_org}    ${instance_org}

GoToRecord Opens A Record From Its Id Alone
    CICD And CRT Dynamic Login
    Should Be True    $login_url == $INSTANCE    msg=login_url is not the org's address after the login
    ${accounts}=    QueryRecords    SELECT Id FROM Account ORDER BY CreatedDate LIMIT 1
    ${id}=    Set Variable    ${accounts}[records][0][Id]
    GoToRecord    ${id}
    ${level}=    Set Log Level    NONE
    TRY
        ${url}=    GetUrl
        ${on_record}=    Evaluate    $id in $url or $id[:15] in $url
        ${via_link}=    Evaluate    'frontdoor' in $url
    FINALLY
        Set Log Level    ${level}
    END
    Log    GoToRecord ${id}: on the record ${on_record}, through Copado's link ${via_link}    console=True
    Should Be True    ${on_record} and not ${via_link}
