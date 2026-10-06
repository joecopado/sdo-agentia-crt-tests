*** Settings ***
Documentation       US-0000032 Block negative Opportunity amounts (SDO Agentia Pipeline, runs in SDO QA).
...                 Acceptance: saving an Opportunity with an Amount below 0 fails with "Amount cannot be negative."
...                 on the Amount field. The test makes its own Account through the API (the Opportunity layout
...                 requires one), fills the New Opportunity form as the Simple Opportunity record type with Amount
...                 -100, saves, sees the message, proves no Opportunity was saved, and deletes its Account.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
A Negative Amount Is Blocked
    [Teardown]      Delete Test Record    Account    ${account_id}
    ${account_id}=  Set Variable    ${EMPTY}
    Login To QA
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key) for its API steps.
    ${company}=     FakerLibrary.Company
    ${company}=     Remove String    ${company}    '
    ${account_id}=  Create Record    Account    Name=${company}
    ${rt}=          QueryRecords    SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND Name = 'Simple Opportunity' AND IsActive = true
    ${rt_id}=       Set Variable    ${rt}[records][0][Id]
    ${name}=        Set Variable    ${company} Renewal
    ${close}=       Get Current Date    increment=30 days    result_format=%m/%d/%Y
    GoTo            ${INSTANCE}/lightning/o/Opportunity/new?recordTypeId\=${rt_id}
    UseModal        On
    TypeText        Opportunity Name    ${name}
    TypeText        Close Date    ${close}
    PickList        Stage    Qualification
    ComboBox        Account Name    ${company}
    PickList        Forecast Category    Pipeline
    TypeText        Amount    -100
    ClickText       Save    partial_match=False
    # the validation message does not render inside the modal, so the modal scope is switched off first
    UseModal        Off
    VerifyText      Amount cannot be negative.    timeout=20
    Log             Blocked as expected: "Amount cannot be negative."    console=True
    ${saved}=       QueryRecords    SELECT Id FROM Opportunity WHERE Name = '${name}'
    Should Be Equal As Integers    ${saved}[totalSize]    0
    Log             Database check: no Opportunity named ${name} was saved    console=True
