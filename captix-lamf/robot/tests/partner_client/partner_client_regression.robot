*** Settings ***
Documentation     Unified dual-mode auth flow.
...               - app_code present  → Suite Setup logs in → cookie headers (X-CLIENT-ID, X-API-KEY, Cookie, app-code)
...               - app_code absent   → no login → HMAC signature headers (X-Timestamp, X-Request-Signature, x-client-id, x-api-key)
...               Override at runtime: robot -v app_code:${NONE} PARTNER_CLIENT__Flow.robot  (HMAC mode)
...               robot PARTNER_CLIENT__Flow.robot  (LOGIN mode, uses variables.robot default)
Suite Setup       Suite Setup Auth
Resource          ../../resources/common.resource
Resource          ../../resources/partner_client/login_flow.resource

*** Test Cases ***
PARTNER_CLIENT_Regression
    [Documentation]    Full LOS regression — auth mode driven by \${app_code}: set=LOGIN, \${NONE}=HMAC

    FOR    ${i}    IN RANGE    0    1

        ${PAN_Number}=    Generate Random PAN
        ${mobile_No}=     Generate Random Mobile Number
        Log To Console    Running PAN=${PAN_Number}, MOBILE=${mobile_No}

        ${status}    ${result}=    Run Keyword And Ignore Error
        ...    PARTNER_CLIENT Regression    ${PAN_Number}    ${mobile_No}    

        IF    "Customer already exists" in "${result}" or "An active loan application already exists" in "${result}"
            Log To Console    Skipping PAN ${PAN_Number} — ${result}
            CONTINUE
        ELSE IF    '${status}' == 'FAIL'
            Fail    Testcase Failed: ${result}
        END

    END

*** Keywords ***
# ─── Auth Setup ───────────────────────────────────────────────────────────────
Suite Setup Auth
    [Documentation]    If app_code is set: login and store cookies as suite vars.
    ...                If app_code is ${NONE}: prepare HMAC mode (no login).
    Set Suite Variable    ${scheme}    partner_client
    IF    $app_code is not None and str($app_code).upper() != 'NONE'
        ${cookies}    ${client_Id}    ${api_key}    ${ac}    ${branchCode}=    TC_01 Login
        Set Suite Variable    ${suite_cookies}      ${cookies}
        Set Suite Variable    ${suite_client_Id}    ${client_Id}
        Set Suite Variable    ${suite_api_key}      ${api_key}
        Set Suite Variable    ${suite_app_code}     ${ac}
        Log To Console    Auth Mode: LOGIN — app_code=${ac}
    ELSE
        Set Suite Variable    ${suite_client_Id}    ${partner_client-client-id}
        Set Suite Variable    ${suite_api_key}      ${partner_client-api-key}
        Log To Console    Auth Mode: HMAC — no login, using gateway HMAC signature
    END

# ─── Full Regression Flow ─────────────────────────────────────────────────────
PARTNER_CLIENT Regression
    [Arguments]    ${PAN_Number}    ${mobile_No}

    ${referenceId}=           TC_02 Dedupe Check              ${PAN_Number}    ${mobile_No}
    ${platformCustId}=        TC_03 Validate OTP              ${referenceId}
    ${loanApp_No}    ${productType}=     TC_04 Create Loan Application    ${PAN_Number}    ${mobile_No}
    ${email_referId}=         TC_05 Initiate Email OTP        ${loanApp_No}
                              TC_06 Validate Email OTP        ${email_referId}
                              TC_07 Aadhaar Link Generation   ${loanApp_No}    ${mobile_No}
                              TC_08 Fetch Aadhaar Details     ${loanApp_No}
                              TC_09 KYC Compliant Check       ${loanApp_No}
                              TC_10 Photo Verification        ${loanApp_No}
                              TC_11 Update Loan               ${loanApp_No}

    ${CAMS_referFetchID}=     TC_12 CAMS Fetch Initiate       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TC_13 CAMS Fetch Validate OTP   ${CAMS_referFetchID}
    ${CAMS_funds}=            TC_14 Eligible Holdings CAMS    ${loanApp_No}    ${CAMS_referFetchID}
    ${CAMS_pledgeRefID}=      TC_15 Pledge Initiate CAMS      ${loanApp_No}    ${CAMS_referFetchID}    ${CAMS_funds}
                              TC_16 Pledge Validate CAMS      ${CAMS_pledgeRefID}

    ${KFin_referFetchID}=     TC_17 Kfintech Fetch Initiate       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TC_18 Kfintech Fetch Validate OTP   ${KFin_referFetchID}
    ${KFIN_funds}=            TC_19 Eligible Holdings KFINTECH    ${loanApp_No}    ${KFin_referFetchID}
    ${KFIN_pledgeRefID}=      TC_20 Pledge Initiate KFINTECH      ${loanApp_No}    ${KFin_referFetchID}    ${KFIN_funds}
                              TC_21 Pledge Validate KFINTECH      ${KFIN_pledgeRefID}

                              TC_22 Eligibility Check         ${loanApp_No}
                              TC_23 Beneficiary Add           ${loanApp_No}
                              TC_24 DigiSign                  ${loanApp_No}
                              TC_25 DigiSign Status           ${loanApp_No}
                              TC_26 mandate initiate          ${loanApp_No}
                              TC_27 mandate status            ${loanApp_No}
                              TC_28 Video KYC                 ${loanApp_No}
                              TC_29 VKYC Check Status         ${loanApp_No}

    IF    $suite_app_code is not None
         TC_30 Logout
    END


