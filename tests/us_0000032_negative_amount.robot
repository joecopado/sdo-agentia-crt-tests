*** Settings ***
Documentation       US-0000032 Block negative Opportunity amounts (SDO Agentia Pipeline, runs in SDO QA).
...                 Acceptance: saving an Opportunity with an Amount below 0 fails with "Amount cannot be negative."
...                 on the Amount field. The test enters -100, saves, sees the message, and (with API access) proves
...                 nothing was saved. No record is created, so there is nothing to clean up.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
A Negative Amount Is Blocked
    Login To QA
    ${company}=     FakerLibrary.Company
    ${company}=     Remove String    ${company}    '
    ${name}=        Set Variable    ${company} Renewal
    ${close}=       Get Current Date    increment=30 days    result_format=%m/%d/%Y
    GoTo            ${INSTANCE}/lightning/o/Opportunity/new
    UseModal        On
    ${picker}=      IsText    Select a record type    timeout=5
    IF    ${picker}
        ClickText    Simple Opportunity
        ClickText    Next    partial_match=False
    END
    TypeText        Opportunity Name    ${name}
    PickList        Stage    Qualification
    TypeText        Close Date    ${close}
    TypeText        Amount    -100
    ClickText       Save    partial_match=False
    # the validation message does not render inside the modal, so the modal scope is switched off first
    UseModal        Off
    VerifyText      Amount cannot be negative.    timeout=20
    Log             Blocked as expected: "Amount cannot be negative."    console=True
    IF    ${API}
        ${saved}=    QueryRecords    SELECT Id FROM Opportunity WHERE Name = '${name}'
        Should Be Equal As Integers    ${saved}[totalSize]    0
        Log    Database check: no Opportunity named ${name} exists    console=True
    END
