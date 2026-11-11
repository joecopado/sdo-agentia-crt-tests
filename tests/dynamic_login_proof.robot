*** Settings ***
Documentation       Proof of the reworked CICD And CRT Dynamic Login, read-only. Started from Copado CI/CD (US-0000039,
...                 SDO dev1), the browser and QForce's API keywords should both use the CI/CD session. Started on
...                 its own in CRT, both should use the job's JWT variables (SDO QA).
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
