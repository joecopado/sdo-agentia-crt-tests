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
