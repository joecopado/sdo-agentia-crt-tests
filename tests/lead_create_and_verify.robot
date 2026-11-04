*** Settings ***
Documentation       Agentia demo: a new Lead saves with the values typed into the form (runs in SDO QA).
...                 Acceptance: a Lead created from the New Lead form (record type Lead) shows its name on the saved
...                 record, and the database holds the first name, last name, title, company and email the form was
...                 given. The test makes up its own values with FakerLibrary and deletes its Lead afterwards.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
A New Lead Saves With The Values Entered
    [Tags]          agentia-demo
    [Teardown]      Delete Test Lead    ${email}
    ${first}=       FakerLibrary.First Name
    ${last}=        FakerLibrary.Last Name
    ${title}=       FakerLibrary.Job
    ${company}=     FakerLibrary.Company
    ${email}=       Convert To Lower Case    ${first}.${last}@example.com
    ${email}=       Replace String Using Regexp    ${email}    [^a-z0-9.@]    ${EMPTY}
    CICD And CRT Dynamic Login
    # App: Sales
    NavigateToApp   LightningSales
    Open New Record Form    Lead    Lead
    UseModal        On
    TypeText        First Name    ${first}
    TypeText        Last Name    ${last}
    TypeText        Title    ${title}
    TypeText        Company    ${company}
    TypeText        Email    ${email}
    ClickText       Save    partial_match=False
    UseModal        Off
    VerifyText      ${first} ${last}    timeout=20
    # Database check: exactly one Lead has this email, and it holds what the form was given
    ${saved}=       QueryRecords    SELECT FirstName, LastName, Title, Company, Status FROM Lead WHERE Email = '${email}'
    Should Be Equal As Integers    ${saved}[totalSize]    1    msg=Expected one Lead with email ${email}, found ${saved}[totalSize].
    Should Be Equal    ${saved}[records][0][FirstName]    ${first}
    Should Be Equal    ${saved}[records][0][LastName]    ${last}
    Should Be Equal    ${saved}[records][0][Title]    ${title}
    Should Be Equal    ${saved}[records][0][Company]    ${company}
    Should Not Be Empty    ${saved}[records][0][Status]    msg=The saved Lead has no Status.

*** Keywords ***
Delete Test Lead
    [Documentation]    Teardown: deletes the Lead this test created, found by its email, if it got that far.
    [Arguments]    ${email}
    ${found}=    QueryRecords    SELECT Id FROM Lead WHERE Email = '${email}'
    FOR    ${lead}    IN    @{found}[records]
        Delete Record    Lead    ${lead}[Id]
        Log    Teardown: deleted Lead ${lead}[Id]    console=True
    END
