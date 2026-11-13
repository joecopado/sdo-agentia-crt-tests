*** Settings ***
Documentation       Proof: QForce's JWTAuthenticate with custom_url, the org's own My Domain address, signs in to a
...                 production org (SDO Prod) and to a sandbox (SDO QA). Three sign-ins that must be refused are refused,
...                 so the two passes mean something. Read-only in both orgs.
...                 SDO QA: the robot's client_id, username and private_key, at the job's jwt_url. SDO Prod: the job's
...                 prod_client_id, prod_username and prod_private_key, at the job's prod_url. None of them is declared
...                 in a file, and logging stays off while a credential is read or used.
...                 Production runs first, so each sign-in has to change which org QForce answers from.
Resource            ../resources/common.robot
Resource            ../resources/custom_url_proof.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
1 A Production Org Signs In At Its Own Address
    ${ok}    ${reason}=    Sign In With    prod    custom_url=${prod_url}
    Should Be True    ${ok}    msg=SDO Prod refused its own address: ${reason}
    Signed In To    ${prod_url}    ${False}
    # the browser too: JwtLogin opens a UI session from the same sign-in
    JwtLogin
    Browser Should Be On    ${prod_url}
    LogScreenshot

2 A Sandbox Signs In At Its Own Address
    ${ok}    ${reason}=    Sign In With    qa    custom_url=${jwt_url}
    Should Be True    ${ok}    msg=SDO QA refused its own address: ${reason}
    Signed In To    ${jwt_url}    ${True}

3 A Sandbox Is Refused At The Production Login Address
    # no sandbox flag and no custom_url: login.salesforce.com, the audience a sandbox must refuse
    ${ok}    ${reason}=    Sign In With    qa
    Should Not Be True    ${ok}    msg=SDO QA signed in at login.salesforce.com, so a sandbox does not check the audience.
    Log    Refused, as expected: ${reason}    console=True

4 A Production Org Is Refused At The Sandbox Login Address
    # what today's guess tries first on every production org: test.salesforce.com
    ${ok}    ${reason}=    Sign In With    prod    sandbox=${True}
    Should Not Be True    ${ok}    msg=SDO Prod signed in at test.salesforce.com.
    Log    Refused, as expected: ${reason}    console=True

5 Sandbox Credentials Are Refused At The Production Address
    # a job pointed at the wrong org's address must fail, never sign in to that other org
    ${ok}    ${reason}=    Sign In With    qa    custom_url=${prod_url}
    Should Not Be True    ${ok}    msg=SDO QA's credentials signed in at SDO Prod's address.
    Log    Refused, as expected: ${reason}    console=True
