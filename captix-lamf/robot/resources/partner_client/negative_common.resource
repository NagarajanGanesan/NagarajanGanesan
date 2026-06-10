*** Settings ***
Documentation     Shared Suite Setup for all PARTNER_CLIENT negative test files.
...               Mirrors PARTNER_CLIENT_Regression.robot's Suite Setup Auth — calls TC_01 Login when
...               app_code is set (LOGIN mode) so cookies/headers are available, otherwise
...               falls through to HMAC mode.
Resource          ../common.resource
Resource          ../build_header.resource
Resource          login_flow.resource

*** Variables ***
# Bad / boundary values reused across negative suites
${BAD_PAN_FORMAT}            ABCDE12345          # only 5 letters + 5 digits, missing trailing letter
${BAD_PAN_SHORT}             ABCDE123F
${BAD_PAN_LONG}              ABCDE12345FGHIJ
${BAD_PAN_LOWERCASE}         abcde1234f
${BAD_PAN_SPECIAL}           ABC@E1234F
${BAD_MOBILE_SHORT}          12345
${BAD_MOBILE_LONG}            123456789012345
${BAD_MOBILE_LEADING}        1234567890          # mobile must start with 6/7/8/9
${BAD_MOBILE_NONNUM}         98765ABCDE
${BAD_EMAIL}                 not-an-email
${BAD_OTP}                   000000
${BAD_OTP_ALPHA}             ABCDEF
${BAD_OTP_SHORT}              123
${BAD_REF_ID}                INVALID_REF_ID_999
${BAD_AADHAAR_SHORT}         123456789
${BAD_AADHAAR_LONG}          1234567890123
${BAD_AADHAAR_NONNUM}        12345678ABCD
${BAD_IFSC}                  XXXX0000000
${BAD_BANK_ACCT}             1
${BAD_PRODUCT_CODE}          ZZ999999999
${BAD_LOAN_APP_NO}           N000000028
${BAD_TEMPLATE_TYPE}         INVALID_TEMPLATE
${BAD_LOGIN_TYPE}            HACKER
${BAD_USERNAME}              non_existent_user_zzz
${BAD_PASSWORD}              wrong_password_123
${BAD_API_KEY}               deadbeef0000000000000000deadbeef0000000000000000deadbeef00000000
${BAD_CLIENT_ID}             00000000000000000000000000
${BAD_APP_CODE}              00000000-0000-0000-0000-000000000000
${SQL_INJECTION}             admin' OR '1'='1
${LONG_STRING_300}            'A' * 300

*** Keywords ***
Suite Setup Auth Negative
    [Documentation]    Same auth pattern as PARTNER_CLIENT_Regression.robot — call TC_01 Login when
    ...                LOGIN mode is requested via ${app_code}, else use HMAC.
    Set Suite Variable    ${scheme}    partner_client
    IF    $app_code is not None and str($app_code).upper() != 'NONE'
        ${cookies}    ${client_Id}    ${api_key}    ${ac}    ${branchCode}=    TC_01 Login
        Set Suite Variable    ${suite_cookies}      ${cookies}
        Set Suite Variable    ${suite_client_Id}    ${client_Id}
        Set Suite Variable    ${suite_api_key}      ${api_key}
        Set Suite Variable    ${suite_app_code}     ${ac}
        Log To Console    Negative Suite: LOGIN — app_code=${ac}
    ELSE
        Set Suite Variable    ${suite_client_Id}    ${partner_client-client-id}
        Set Suite Variable    ${suite_api_key}      ${partner_client-api-key}
        Log To Console    Negative Suite: HMAC mode (no login)
    END

POST Negative
    [Documentation]    Wrapper that issues a POST and tolerates non-2xx responses
    ...                so we can assert the actual error code.
    [Arguments]    ${alias}    ${path}    ${body}    ${headers}
    ${response}=    POST On Session    ${alias}    ${path}
    ...    json=${body}    headers=${headers}    expected_status=any
    RETURN    ${response}

PUT Negative
    [Arguments]    ${alias}    ${path}    ${body}    ${headers}
    ${response}=    PUT On Session    ${alias}    ${path}
    ...    json=${body}    headers=${headers}    expected_status=any
    RETURN    ${response}

GET Negative
    [Arguments]    ${alias}    ${path}    ${headers}    ${params}=${NONE}
    ${response}=    GET On Session    ${alias}    ${path}
    ...    headers=${headers}    params=${params}    expected_status=any
    RETURN    ${response}

Assert Status And Log
    [Documentation]    Asserts response code matches expected and logs body summary.
    [Arguments]    ${tc}    ${response}    ${expected_status}
    Should Be Equal As Integers    ${response.status_code}    ${expected_status}
    Log To Console    ${tc}: status=${response.status_code} body=${response.text}
