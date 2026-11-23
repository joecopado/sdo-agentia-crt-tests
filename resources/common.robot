*** Settings ***
Documentation       Shared setup for the SDO Agentia CRT tests: the browser, and cleanup of what a test created.
...                 The login lives in its own file, in two versions that do the same thing. A suite imports ONE of
...                 them: resources/login_robot.robot (Robot Framework) or resources/CicdDynamicLogin.py (Python).
Library             QForce
Library             QWeb
Library             String
Library             DateTime
Library             Collections
Library             FakerLibrary

*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser    about:blank    chrome
    SetConfig    LineBreak    ${EMPTY}
    SetConfig    DefaultTimeout    20s

End Suite
    Close All Browsers

Delete Test Record
    [Documentation]    Teardown: delete one record a test created through the API, if it got that far.
    [Arguments]    ${sobject}    ${record_id}
    IF    '${record_id}' != '${EMPTY}'
        Delete Record    ${sobject}    ${record_id}
        Log    Teardown: deleted ${sobject} ${record_id}    console=True
    END

Create Test Account
    [Documentation]    Creates an Account through the API for this test. Delete Test Account removes it in teardown.
    [Arguments]    ${name}
    Should Be True    ${API}    msg=This test needs the job's JWT variables (client_id, username, private_key) for its API steps.
    ${id}=    Create Record    Account    Name=${name}
    Set Test Variable    ${TEST_ACCOUNT_ID}    ${id}

Delete Test Account
    [Documentation]    Teardown: deletes the Account that Create Test Account made, if the test got that far.
    Delete Test Record    Account    ${TEST_ACCOUNT_ID}

Open New Record Form
    [Documentation]    Opens an object's New form by its URL. Name a record type to open the form as that type; leave it
    ...                out to open the object's default form (an object with several record types available to the user
    ...                may first show Salesforce's record type choice).
    [Arguments]    ${object}    ${record_type}=${EMPTY}
    IF    '${record_type}' == '${EMPTY}'
        GoTo    ${INSTANCE}/lightning/o/${object}/new
    ELSE
        ${rt}=    QueryRecords    SELECT Id FROM RecordType WHERE SobjectType = '${object}' AND Name = '${record_type}' AND IsActive = true
        Should Be True    ${rt}[totalSize] == 1    msg=No active record type named '${record_type}' on ${object}.
        GoTo    ${INSTANCE}/lightning/o/${object}/new?recordTypeId\=${rt}[records][0][Id]
    END

Test Account Should Have No Opportunities
    [Documentation]    Database check: no Opportunity was saved on the Account this test created.
    ${saved}=    QueryRecords    SELECT Id FROM Opportunity WHERE AccountId = '${TEST_ACCOUNT_ID}'
    Should Be Equal As Integers    ${saved}[totalSize]    0    msg=An Opportunity was saved on the test Account.
