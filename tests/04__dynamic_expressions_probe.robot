*** Settings ***
Documentation       Probe: what the Copado CI/CD Test record's Variables (dynamic expressions) deliver to the run, next
...                 to the loginUrl. Not part of the login. Read-only; prints shapes and lengths, never a value.
...                 A name still NOT_SET did not arrive (the declarations below are the fallback).
Library             ../resources/dx_probe.py

*** Variables ***
${dx_context_url}           NOT_SET
${dx_context_session}       NOT_SET
${dx_source_url}            NOT_SET
${dx_source_session}        NOT_SET
${dx_destination_session}   NOT_SET
${dx_story_name}            NOT_SET
${dx_literal}               NOT_SET

*** Test Cases ***
What The Test Record's Variables Delivered
    ${lines}=    Describe Probe Variables    dx_context_url    dx_context_session    dx_source_url    dx_source_session
    ...    dx_destination_session    dx_story_name    dx_literal    loginUrl
    FOR    ${line}    IN    @{lines}
        Log    ${line}    console=True
    END

A Delivered Session Answers SOQL
    ${result}=    Session Answers SOQL    dx_context_session    dx_context_url    dx_source_session    dx_source_url
    Log    ${result}    console=True
