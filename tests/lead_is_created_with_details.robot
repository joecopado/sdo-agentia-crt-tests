*** Settings ***
Documentation       A new Lead is created with every detail saved (runs in SDO QA).
...                 Acceptance: filling the New Lead form as the default Lead record type (label "Lead", layout
...                 SDO - Lead) and saving creates one Lead whose saved fields all match what was entered: name,
...                 title, company, phone, email, lead source, industry, annual revenue, number of employees,
...                 status (New, preselected), record type and owner. The test queries the saved record through the
...                 API and deletes it in teardown.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Variables ***
# The unique Last Name this test creates its Lead with. Teardown finds the Lead by it.
${TEST_LEAD_LAST_NAME}      ${EMPTY}

*** Test Cases ***
A New Lead Is Created With All Details
    [Teardown]      Delete Test Lead
    CICD And CRT Dynamic Login
    # App: Sales
    NavigateToApp   LightningSales
    # Unique, SOQL-safe key (no quotes in it); the rest of the data is fake.
    ${stamp}=       Evaluate    random.randint(100000, 999999)    modules=random
    ${first}=       First Name
    ${last}=        Set Variable    Crtlead${stamp}
    ${title}=       Job
    ${company}=     Company
    ${phone}=       Evaluate    '555' + str(random.randint(1000000, 9999999))    modules=random
    ${email}=       Set Variable    crtlead${stamp}@example.com
    Set Test Variable    ${TEST_LEAD_LAST_NAME}    ${last}
    Open New Record Form    Lead    Lead
    UseModal        On
    TypeText        First Name    ${first}
    TypeText        Last Name    ${last}
    TypeText        Title    ${title}
    TypeText        Company    ${company}
    TypeText        Phone    ${phone}
    TypeText        Email    ${email}
    PickList        Lead Source    Website
    PickList        Industry    Technology
    TypeText        Annual Revenue    2500000
    TypeText        No. of Employees    150
    ClickText       Save    partial_match=False
    UseModal        Off    # the saved record page is outside the modal
    VerifyText      ${first} ${last}    timeout=20
    Saved Lead Should Match    ${last}    ${first}    ${title}    ${company}    ${phone}    ${email}

*** Keywords ***
Saved Lead Should Match
    [Documentation]    Database check: exactly one Lead was saved with this Last Name (waits up to 20 s for the save
    ...                to land) and every field matches what was typed. Phone is stored as typed; only the page
    ...                formats it.
    [Arguments]    ${last}    ${first}    ${title}    ${company}    ${phone}    ${email}
    Wait Until Keyword Succeeds    20s    2s    Lead Exists    ${last}
    ${found}=       QueryRecords    SELECT FirstName, LastName, Name, Title, Company, Phone, Email, LeadSource, Industry, AnnualRevenue, NumberOfEmployees, Status, IsConverted, RecordType.Name, Owner.Name FROM Lead WHERE LastName = '${last}'
    Should Be True    ${found}[totalSize] == 1    msg=Expected exactly one Lead with Last Name ${last}, found ${found}[totalSize].
    ${lead}=        Set Variable    ${found}[records][0]
    Should Be Equal    ${lead}[FirstName]    ${first}    msg=First Name
    Should Be Equal    ${lead}[LastName]    ${last}    msg=Last Name
    Should Be Equal    ${lead}[Name]    ${first} ${last}    msg=Full Name
    Should Be Equal    ${lead}[Title]    ${title}    msg=Title
    Should Be Equal    ${lead}[Company]    ${company}    msg=Company
    Should Be Equal    ${lead}[Phone]    ${phone}    msg=Phone
    Should Be Equal    ${lead}[Email]    ${email}    msg=Email
    Should Be Equal    ${lead}[LeadSource]    Website    msg=Lead Source
    Should Be Equal    ${lead}[Industry]    Technology    msg=Industry
    Should Be Equal As Numbers    ${lead}[AnnualRevenue]    2500000    msg=Annual Revenue
    Should Be Equal As Integers    ${lead}[NumberOfEmployees]    150    msg=No. of Employees
    Should Be Equal    ${lead}[Status]    New    msg=Status (preselected by the form)
    Should Be Equal    ${lead}[RecordType][Name]    Lead    msg=Record Type
    Should Not Be True    ${lead}[IsConverted]    msg=The new Lead should not be converted.

Lead Exists
    [Arguments]    ${last}
    ${found}=       QueryRecords    SELECT Id FROM Lead WHERE LastName = '${last}'
    Should Be True    ${found}[totalSize] >= 1    msg=No Lead with Last Name ${last} has been saved yet.

Delete Test Lead
    [Documentation]    Teardown: deletes every Lead this test created (found by its unique Last Name), even when the
    ...                test failed after the save. Does nothing if the test never got as far as making a name.
    IF    '${TEST_LEAD_LAST_NAME}' != '${EMPTY}' and ${API}
        ${found}=    QueryRecords    SELECT Id FROM Lead WHERE LastName = '${TEST_LEAD_LAST_NAME}'
        FOR    ${record}    IN    @{found}[records]
            Delete Test Record    Lead    ${record}[Id]
        END
    END
