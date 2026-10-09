*** Settings ***
Documentation       Build Agent demo: an Account becomes a Customer (runs in SDO QA, selected by the tag
...                 build-agent-demo). Acceptance: changing an Account's Type to Customer saves, and the saved
...                 Account shows Type Customer. The demo Account "Bluebird Outfitters" (no parent account, no
...                 Industry) is set up by plant.sh / reset.sh in ~/Agentia/build-agent-demo.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
An Account Becomes A Customer
    [Tags]          build-agent-demo
    Login To QA
    Open Sales App
    Open Account    Bluebird Outfitters
    ClickText       Edit    partial_match=False
    UseModal        On
    PickList        Type    Customer
    ClickText       Save    partial_match=False
    UseModal        Off
    VerifyField     Type    Customer
    Saved Account Type Should Be    Bluebird Outfitters    Customer

*** Keywords ***
Open Sales App
    [Documentation]    Lands in the Sales app first, so the record opens in a known app (an app URL needs its 06m Id).
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key).
    ${app}=    QueryRecords    SELECT DurableId FROM AppDefinition WHERE DeveloperName = 'LightningSales'
    Should Be True    ${app}[totalSize] == 1    msg=No Sales app (LightningSales) in this org.
    GoTo    ${INSTANCE}/lightning/app/${app}[records][0][DurableId]

Open Account
    [Documentation]    Opens the one Account with this name by its record URL.
    [Arguments]    ${name}
    ${found}=    QueryRecords    SELECT Id FROM Account WHERE Name = '${name}'
    Should Be True    ${found}[totalSize] == 1    msg=Expected exactly one Account named '${name}', found ${found}[totalSize].
    GoTo    ${INSTANCE}/lightning/r/Account/${found}[records][0][Id]/view
    VerifyText    ${name}    timeout=20

Saved Account Type Should Be
    [Documentation]    Database check: the Account's saved Type (waits up to 20 s for the save to land).
    [Arguments]    ${name}    ${type}
    Wait Until Keyword Succeeds    20s    2s    Account Type Is    ${name}    ${type}

Account Type Is
    [Arguments]    ${name}    ${type}
    ${found}=    QueryRecords    SELECT Type FROM Account WHERE Name = '${name}'
    Should Be Equal    ${found}[records][0][Type]    ${type}    msg=The saved Account's Type is ${found}[records][0][Type], not ${type}.
