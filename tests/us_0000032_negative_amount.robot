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
    [Teardown]      Delete Test Account
    Login To QA
    ${company}=     Company
    ${close}=       Get Current Date    increment=30 days    result_format=%m/%d/%Y
    Create Test Account    ${company}
    Open New Record Form    Opportunity    Simple Opportunity
    UseModal        On
    TypeText        Opportunity Name    ${company} Renewal
    TypeText        Close Date    ${close}
    PickList        Stage    Qualification
    ComboBox        Account Name    ${company}
    PickList        Forecast Category    Pipeline
    TypeText        Amount    -100
    ClickText       Save    partial_match=False
    UseModal        Off    # the validation message shows outside the modal
    VerifyText      Amount cannot be negative.    timeout=20
    Test Account Should Have No Opportunities
