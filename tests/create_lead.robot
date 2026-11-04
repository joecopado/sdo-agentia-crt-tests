*** Settings ***
Documentation       Create a Lead through the New Lead form and validate what was saved (runs in SDO QA).
...                 The test opens the New Lead form as the default "Lead" record type (SDO - Lead layout: Name and
...                 Status required, Company required by Salesforce), fills name, company, title, phone, email,
...                 Lead Source and Industry with generated values, saves, then validates the saved Lead twice:
...                 on the record page, and in the database with QueryRecords. The Lead is deleted in teardown.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Variables ***
${LEAD_ID}          ${EMPTY}

*** Test Cases ***
A Lead Is Created With The Expected Values
    [Tags]          create-lead
    [Teardown]      Delete Test Lead
    CICD And CRT Dynamic Login
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key) for its database checks.
    # App: Sales
    NavigateToApp   LightningSales
    ${first}=       First Name
    ${suffix}=      Evaluate    str(random.randint(100000, 999999))    modules=random
    ${last}=        Set Variable    Crt${suffix}
    ${company}=     Company
    ${email}=       Set Variable    ${first.lower()}.${last.lower()}@example.com
    ${phone}=       Set Variable    4155550142
    Open New Record Form    Lead    Lead
    UseModal        On
    TypeText        First Name    ${first}
    TypeText        Last Name     ${last}
    TypeText        Company       ${company}
    TypeText        Title         QA Engineer
    TypeText        Phone         ${phone}
    TypeText        Email         ${email}
    PickList        Lead Source   Website
    PickList        Industry      Technology
    ClickText       Save          partial_match=False
    UseModal        Off
    # Validation 1: the record page shows what was entered
    VerifyText      ${first} ${last}    timeout=20
    VerifyField     Company       ${company}
    VerifyField     Title         QA Engineer
    VerifyField     Lead Source   Website
    VerifyField     Industry      Technology
    # Validation 2: the database holds what was entered
    Saved Lead Should Match    ${last}    ${first}    ${company}    QA Engineer    ${email}    Website    Technology

*** Keywords ***
Saved Lead Should Match
    [Documentation]    Database check: finds the one Lead by its unique last name, keeps its Id for teardown, and
    ...                compares every field the test entered, plus the record type and a populated Status.
    [Arguments]    ${last}    ${first}    ${company}    ${title}    ${email}    ${source}    ${industry}
    Wait Until Keyword Succeeds    20s    2s    Lead Exists    ${last}
    ${found}=       QueryRecords    SELECT Id, FirstName, LastName, Company, Title, Email, LeadSource, Industry, Status, IsConverted, RecordType.Name FROM Lead WHERE LastName = '${last}'
    Should Be Equal As Integers    ${found}[totalSize]    1    msg=Expected exactly one Lead with last name ${last}.
    ${lead}=        Set Variable    ${found}[records][0]
    Set Test Variable    ${LEAD_ID}    ${lead}[Id]
    Should Be Equal    ${lead}[FirstName]     ${first}       msg=Saved First Name is ${lead}[FirstName].
    Should Be Equal    ${lead}[LastName]      ${last}        msg=Saved Last Name is ${lead}[LastName].
    Should Be Equal    ${lead}[Company]       ${company}     msg=Saved Company is ${lead}[Company].
    Should Be Equal    ${lead}[Title]         ${title}       msg=Saved Title is ${lead}[Title].
    Should Be Equal    ${lead}[Email]         ${email}       msg=Saved Email is ${lead}[Email].
    Should Be Equal    ${lead}[LeadSource]    ${source}      msg=Saved Lead Source is ${lead}[LeadSource].
    Should Be Equal    ${lead}[Industry]      ${industry}    msg=Saved Industry is ${industry}, not ${lead}[Industry].
    Should Be Equal    ${lead}[RecordType][Name]    Lead     msg=Saved record type is ${lead}[RecordType][Name].
    Should Not Be Empty    ${lead}[Status]    msg=The saved Lead has no Status.
    Should Not Be True     ${lead}[IsConverted]    msg=A new Lead should not be converted.

Lead Exists
    [Arguments]    ${last}
    ${found}=       QueryRecords    SELECT Id FROM Lead WHERE LastName = '${last}'
    Should Be True    ${found}[totalSize] >= 1    msg=No Lead with last name ${last} yet.

Delete Test Lead
    [Documentation]    Teardown: deletes the Lead this test created, if it got that far.
    Delete Test Record    Lead    ${LEAD_ID}
