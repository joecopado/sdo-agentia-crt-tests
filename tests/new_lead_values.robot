*** Settings ***
Documentation       A new Lead is created and keeps the values it was given (SDO Agentia Pipeline). Acceptance: the
...                 New Lead form (record type "Lead", layout SDO - Lead) saves with a First Name, Last Name, Company,
...                 Email and Title, the saved record page shows them, and the database holds the same values with
...                 Status New and the Lead record type. The values are made with FakerLibrary, and the test deletes
...                 the Lead it created.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Variables ***
${LEAD_LAST}        ${EMPTY}

*** Test Cases ***
A New Lead Is Created With Its Values
    [Teardown]      Delete Test Lead
    CICD And CRT Dynamic Login
    # App: Sales
    NavigateToApp   LightningSales
    ${first}=       Clean Fake      First Name
    ${last}=        Clean Fake      Last Name
    ${last}=        Catenate        SEPARATOR=    ${last}    ${{random.randint(1000, 9999)}}
    ${company}=     Clean Fake      Company
    ${title}=       Clean Fake      Job
    ${email}=       Evaluate        re.sub(r'[^a-z0-9]', '', '${first}${last}'.lower()) + '@example.com'    modules=re
    Set Test Variable    ${LEAD_LAST}    ${last}
    Open New Record Form    Lead    Lead
    UseModal        On
    TypeText        First Name    ${first}
    TypeText        Last Name     ${last}
    TypeText        Company       ${company}
    TypeText        Email         ${email}
    TypeText        Title         ${title}
    ClickText       Save    partial_match=False
    UseModal        Off    # the new record page is not a modal
    VerifyText      ${first} ${last}    timeout=20
    VerifyField     Company    ${company}
    VerifyField     Title      ${title}
    Saved Lead Should Match    ${first}    ${last}    ${company}    ${email}    ${title}

*** Keywords ***
Clean Fake
    [Documentation]    A FakerLibrary value with only letters, digits and spaces, so it is safe in a SOQL string.
    [Arguments]    ${provider}
    ${raw}=    Run Keyword    ${provider}
    ${clean}=    Evaluate    re.sub(r'[^A-Za-z0-9 ]', '', $raw).strip()    modules=re
    RETURN    ${clean}

Saved Lead Should Match
    [Documentation]    Database check: the one saved Lead holds the values the form was given (waits up to 20 s for the save).
    [Arguments]    ${first}    ${last}    ${company}    ${email}    ${title}
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key).
    Wait Until Keyword Succeeds    20s    2s    Lead Has Values    ${first}    ${last}    ${company}    ${email}    ${title}

Lead Has Values
    [Arguments]    ${first}    ${last}    ${company}    ${email}    ${title}
    ${found}=    QueryRecords    SELECT FirstName, LastName, Company, Email, Title, Status, RecordType.Name FROM Lead WHERE LastName = '${last}'
    Should Be Equal As Integers    ${found}[totalSize]    1    msg=Expected exactly one Lead with Last Name ${last}, found ${found}[totalSize].
    ${lead}=    Set Variable    ${found}[records][0]
    Should Be Equal    ${lead}[FirstName]    ${first}    msg=Saved First Name is ${lead}[FirstName], not ${first}.
    Should Be Equal    ${lead}[LastName]     ${last}     msg=Saved Last Name is ${lead}[LastName], not ${last}.
    Should Be Equal    ${lead}[Company]      ${company}  msg=Saved Company is ${lead}[Company], not ${company}.
    Should Be Equal    ${lead}[Email]        ${email}    msg=Saved Email is ${lead}[Email], not ${email}.
    Should Be Equal    ${lead}[Title]        ${title}    msg=Saved Title is ${lead}[Title], not ${title}.
    Should Be Equal    ${lead}[Status]       New         msg=Saved Status is ${lead}[Status], not New.
    Should Be Equal    ${lead}[RecordType][Name]    Lead    msg=Saved record type is ${lead}[RecordType][Name], not Lead.

Delete Test Lead
    [Documentation]    Teardown: deletes the Lead(s) with this test's Last Name through the API, if the test got that far.
    ${api}=    Get Variable Value    ${API}    ${False}
    IF    ${api} and '${LEAD_LAST}' != '${EMPTY}'
        ${found}=    QueryRecords    SELECT Id FROM Lead WHERE LastName = '${LEAD_LAST}'
        FOR    ${rec}    IN    @{found}[records]
            Delete Test Record    Lead    ${rec}[Id]
        END
    END
