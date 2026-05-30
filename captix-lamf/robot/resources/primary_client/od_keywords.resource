*** Settings ***
Documentation     PRIMARY_CLIENT Overdraft (OD) flow keywords. Auth-mode agnostic — headers built via BuildHeader.
Resource     ../common.resource
Resource     ../build_header.resource
Library      ../../libraries/MongoManager.py     env=qa

*** Keywords ***
TC_02 Dedupe Check
    [Arguments]       ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    [Documentation]    Builds request body based on suite-level ${DEDUPE_BY}:
    ...                PAN → {"pan": ...}; MOBILE → {"mobileNumber": ...}; LENDER_CUST_ID → {"lenderCustomerId": ...}
    Create Session    Dedupe_check     url=${QA_URL}    verify=true
    IF    '${DEDUPE_BY}' == 'PAN'
        ${body}=    Create Dictionary    pan=${PAN_Number}
    ELSE IF    '${DEDUPE_BY}' == 'MOBILE'
        ${body}=    Create Dictionary    mobileNumber=${mobile_No}
    ELSE IF    '${DEDUPE_BY}' == 'LENDER_CUST_ID'
        ${body}=    Create Dictionary    lenderCustomerId=${lender_cust_id}
    ELSE
        Fail    Invalid DEDUPE_BY '${DEDUPE_BY}'. Use PAN, MOBILE, or LENDER_CUST_ID.
    END
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    Dedupe_check    /api/v1/dedupe-check
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_INITIATED
    ${referenceId}=    Set Variable    ${json["data"]["referenceId"]}
    Should Not Be Empty    ${referenceId}
    Log To Console    TC_02 Dedupe Check: ${json["status"]["message"]}
    RETURN    ${referenceId}

TC_03 Validate OTP
    [Arguments]    ${referenceId}
    Create Session    Validate_otp    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${referenceId}
    ...    otp=${DEDUPE_OTP}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Validate_otp    /api/v1/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable        ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_VALIDATED
    ${platformCustomerId}=    Set Variable    ${json["data"]["platformCustomerId"]}
    Should Not Be Empty    ${platformCustomerId}
    Log To Console     TC_03 Validate OTP: ${json["status"]["message"]}
    RETURN    ${platformCustomerId}