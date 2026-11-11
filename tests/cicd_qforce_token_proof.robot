*** Settings ***
Documentation     Proof: under Copado CI/CD, QForce's API keywords run on the session in the loginUrl variable once
...               the resource file hands it over, whether called from the resource file or from this test file.
...               Read-only: SOQL, Get Record, and an Execute Apex that only writes a debug line.
Resource          ../resources/common.robot
Suite Setup       CICD Token Into QForce

*** Variables ***
# the proof runs from US-0000039, whose environment is SDO dev1
${EXPECTED_ORG}    00DWC00000EPajR2AT

*** Test Cases ***
QueryRecords From The Test File
    Skip If    not ${QFORCE_ON_CICD_TOKEN}    No CI/CD session in this run: COULD-NOT-CHECK
    ${org}=    QueryRecords    SELECT Id, Name FROM Organization
    Log    Organization ${org}[records][0][Id] (${org}[records][0][Name])    console=True
    Should Be Equal    ${org}[records][0][Id]    ${EXPECTED_ORG}

Get Record From The Resource File
    Skip If    not ${QFORCE_ON_CICD_TOKEN}    No CI/CD session in this run: COULD-NOT-CHECK
    ${name}=    Organization Name From The Resource File
    Log    Organization name through the resource file: ${name}    console=True
    Should Not Be Empty    ${name}

Execute Apex From The Test File
    Skip If    not ${QFORCE_ON_CICD_TOKEN}    No CI/CD session in this run: COULD-NOT-CHECK
    # QForce raises when the script does not compile or run, so a return means it ran
    ${result}=    Execute Apex    System.debug('CI/CD token proof');
    Log    Execute Apex returned: ${result}    console=True

GetInstanceUrl Matches The loginUrl Host
    Skip If    not ${QFORCE_ON_CICD_TOKEN}    No CI/CD session in this run: COULD-NOT-CHECK
    ${url}=    GetInstanceUrl
    Log    GetInstanceUrl: ${url}    console=True
    Should Be Equal    ${url}    ${CICD_HOST}
