*** Settings ***
Documentation       Stock QForce under Copado CI/CD, BEFORE any login keyword: does QForce have an API session of its own?
...                 Copado passes only the loginUrl, so QForce's code says no: QueryRecords and JwtLoginAs should fail
...                 until a login hands QForce the session. This suite runs first, while nothing has done that yet.
...                 Read-only. Run on its own in CRT, there is no Copado session, so it is skipped.
Resource            ../resources/common.robot
Suite Setup         Setup Browser
Suite Teardown      End Suite

*** Test Cases ***
QueryRecords And JwtLoginAs Without A Login Keyword
    # Copado's link carries a live session: logging stays off while it is read and opened
    ${level}=    Set Log Level    NONE
    TRY
        ${link}=    Get Variable Value    ${loginUrl}    ${EMPTY}
        ${cicd}=    Evaluate    'sid=' in $link
        IF    ${cicd}    GoTo    ${link}
    FINALLY
        Set Log Level    ${level}
    END
    Skip If    not ${cicd}    Not a Copado CI/CD run: there is no Copado session to test against.
    LogScreenshot
    ${query}    ${query_error}=    Run Keyword And Ignore Error    QueryRecords    SELECT Id FROM Organization
    ${login_as}    ${login_as_error}=    Run Keyword And Ignore Error    JwtLoginAs    Cindy Central
    Log    Stock QForce under CI/CD, no login keyword: QueryRecords ${query}, JwtLoginAs ${login_as}    console=True
    Should Be Equal    ${query}    FAIL    msg=QueryRecords worked with no login keyword: QForce had an API session of its own.
    Should Be Equal    ${login_as}    FAIL    msg=JwtLoginAs worked with no login keyword: QForce had an API session of its own.
