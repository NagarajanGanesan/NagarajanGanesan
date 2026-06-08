*** Settings ***
Documentation     Positive test cases for Login and Logout.
...               Login User fetches credentials from DB dynamically and calls
...               POST /api/v1/auth/login. Logout User calls GET /api/v1/auth/logout.
Resource          ../variables.resource
Resource          ../build_header.resource

*** Keywords ***
# ─── Login ────────────────────────────────────────────────────────────────────
TC_01 Login
    [Documentation]    POST /api/v1/auth/login — DB-driven credentials, returns cookies + client info
    Create Session     user_login     url=${PARTNER_CLIENT_URL}     verify=true

    ${db}=    Get From Dictionary       ${DB_CONFIGS}    ${ENV}
    Connect To Database    psycopg2     ${db}[name]      ${db}[Username]     ${db}[Password]     ${db}[Host]     ${db}[Port]    None
    ${access_token}     Query     SELECT api_key, client_id FROM ${partner_client_schemeName}.partner_product_config WHERE app_code = '${app_code}';

    ${key&Id}      Get From List     ${access_token}    0
    ${api_key}     Get From List     ${key&Id}          0
    ${client_Id}   Get From List     ${key&Id}          1
    Log  clientId: ${client_Id}
    Set Suite Variable    ${api_key}
    Set Suite Variable    ${client_Id}

    Disconnect From Database

    ${headers}         Create Dictionary    Content-Type=application/json
    ...    X-CLIENT-ID=${client_Id}
    ...    X-API-KEY=${api_key}
    ...    app-code=${app_code}
    ${body}    Create Dictionary
    ...        username=${userName}
    ...        userpassword=${password}
    ...        login_type=${AD_login}
    ${response}        POST On Session      user_login     /api/v1/auth/adlogin     json=${body}     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}

    ${json_data}       Convert String To Json    ${response.content}
    ${message}         Get Value From Json       ${json_data}     status.code
    ${msg}             Get From List             ${message}       0
    ${branch}          Get Value From Json       ${json_data}     data.branch_code
    ${branchCode}      Get From List             ${branch}        0
    ${name}            Get Value From Json       ${json_data}     data.user_name
    ${user_name}       Get From List             ${name}          0

    ${cookies}=          Set Variable    ${response.cookies.get_dict()}
    ${access_token}=     Get From Dictionary    ${cookies}     ${app_code}_x-access-token
    ${refresh_token}=    Get From Dictionary    ${cookies}     ${app_code}_x-refresh-token
    ${userId}=           Get From Dictionary    ${cookies}     ${app_code}_user_id
    ${userRole}          Get From Dictionary    ${cookies}     ${app_code}_user_roles

    Log    ${access_token}
    Log    ${refresh_token}

    ${cookies}    Set Variable    ${app_code}_x-access-token=${access_token}; ${app_code}_x-refresh-token=${refresh_token}; ${app_code}_user_id=${userId}; ${app_code}_user_roles=${userRole}

    Log To Console     TC_01: ${user_name} ${msg}

    RETURN     ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${branchCode}

TC_02 Dedupe Check
    [Arguments]       ${PAN_Number}    ${mobile_No}
    Create Session    Dedupe_check     url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    pan=${PAN_Number}
    ...    mobileNumber=${mobile_No}
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    Dedupe_check    /api/v1/dedupe-check
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_INITIATED
    ${referenceId}=    Set Variable    ${json["data"]["referenceId"]}
    Should Not Be Empty    ${referenceId}
    Log To Console    TC_02: ${json["status"]["message"]}
    RETURN    ${referenceId}

TC_03 Validate OTP
    [Arguments]    ${referenceId}
    Create Session    Validate_otp    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${referenceId}
    ...    otp=${DEDUPE_OTP}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Validate_otp    /api/v1/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_VALIDATED
    ${platformCustomerId}=    Set Variable    ${json["data"]["platformCustomerId"]}
    Should Not Be Empty    ${platformCustomerId}
    Log To Console     TC_03: ${json["status"]["message"]}
    RETURN    ${platformCustomerId}

TC_04 Create Loan Application
    [Arguments]    ${PAN_Number}    ${mobile_No}
    Create Session    create_LoanApp    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    pan=${PAN_Number}
    ...    productCode=${productCode}
    ...    mobileNumber=${mobile_No}
    ...    email=${EMAIL}
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    create_LoanApp    /api/v1/loan-application/apply
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    LOAN_APPLICATION_CREATED
    ${loanApp_No}=    Set Variable    ${json["data"]["loanApplicationNo"]}
    ${productType}=   Set Variable    ${json["data"]["productType"]}
    Should Not Be Empty    ${loanApp_No}
    Log To Console     TC_04: ${json["status"]["message"]}, LoanApp_No: ${loanApp_No}
    RETURN    ${loanApp_No}    ${productType}

TC_05 Initiate Email OTP
    [Arguments]    ${loanApp_No}
    Create Session    email_init    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    email=${EMAIL}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    email_init    /api/v1/kyc/email/initiate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_INITIATED
    ${email_referId}=    Set Variable    ${json["data"]["referenceId"]}
    Should Not Be Empty    ${email_referId}
    Log To Console     TC_05: ${json["status"]["message"]}, RefID: ${email_referId}
    RETURN    ${email_referId}

TC_06 Validate Email OTP
    [Arguments]    ${email_referId}
    Create Session    email_validate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${email_referId}
    ...    otp=123456
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    email_validate    /api/v1/kyc/email/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_VALIDATED
    Should Be Equal    ${json["data"]["platformStatus"]}    COMPLETED
    Should Be Equal    ${json["data"]["externalStatus"]}    EMAIL_VERIFIED
    Log To Console     TC_06: ${json["status"]["message"]}

TC_07 Aadhaar Link Generation
    [Arguments]    ${loanApp_No}    ${mobile_No}
    Create Session    aadhaar_link    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    aadhaarNo=${AADHAAR_NO}
    ...    redirectionUrl=${REDIRECT_URL}
    ...    mobileNumber=${mobile_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    aadhaar_link    /api/v1/aadhaar/initiate
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    AADHAAR_VERIFICATION
    Should Be Equal    ${json["data"]["platformStatus"]}    INITIATED
    Should Be Equal    ${json["data"]["externalStatus"]}    AADHAAR_VERIFICATION_INITIATED
    Log To Console     TC_07: ${json["status"]["message"]}

TC_08 Fetch Aadhaar Details
    [Arguments]    ${loanApp_No}
    Create Session    fetch_aadhaar_status    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    fetch_aadhaar_status    /api/v1/aadhaar/status
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    AADHAAR_VALIDATED
    Should Be Equal    ${json["data"]["platformStatus"]}    AADHAAR_VERIFICATION_SUCCESS
    Should Be Equal    ${json["data"]["externalStatus"]}    COMPLETED
    Log To Console     TC_08: ${json["status"]["message"]}

TC_09 KYC Compliant Check
    [Arguments]    ${loanApp_No}
    Create Session    kyc_check    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    nameAsPerPan=${NAME_AS_PER_PAN}
    ...    dobAsPerPan=${DOB_AS_PER_PAN}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    kyc_check    /api/v1/kyc/check
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    KYC_CHECKS
    Should Be Equal    ${json["data"]["platformStatus"]}    COMPLETED
    Should Be Equal    ${json["data"]["externalStatus"]}    KYC_VERIFIED
    Log To Console     TC_09: ${json["status"]["message"]}

TC_10 Photo Verification
    [Arguments]    ${loanApp_No}
    Create Session    photo_verification    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    fileBase64=${fileBase64}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    photo_verification    /api/v1/kyc/photo-verification
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    PHOTO_VERIFICATION
    Should Be Equal    ${json["data"]["platformStatus"]}    COMPLETED
    Should Be Equal    ${json["data"]["externalStatus"]}    PHOTO_VERIFICATION_SUCCESS
    Log To Console     TC_10: ${json["status"]["message"]}

TC_11 Update Loan
    [Arguments]    ${loanApp_No}
    Create Session    update_loan    url=${PARTNER_CLIENT_URL}    verify=true
    ${communication_address}=    Create Dictionary
    ...    addressLine1=Flat No. 123
    ...    addressLine2=Sample Apartments, Sample Locality
    ...    addressLine3=
    ...    city=Sample City
    ...    state=Sample State
    ...    pincode=600001
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    fatherName=${FATHER_NAME}
    ...    sameAsPermanentAddress=${True}
    ...    communicationAddress=${communication_address}
    ${headers}=    Build Headers    ${body}
    ${response}=    PUT On Session    update_loan    /api/v1/loan-application/update
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    LOAN_UPDATE
    Should Be Equal    ${json["data"]["platformStatus"]}    COMPLETED
    Should Be Equal    ${json["data"]["externalStatus"]}    LOAN_UPDATED
    Log To Console     TC_11: ${json["status"]["message"]}

# ─── CAMS ─────────────────────────────────────────────────────────────────────
TC_12 CAMS Fetch Initiate
    [Arguments]       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
    Create Session    CAMS_initiate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    pan=${PAN_Number}
    ...    mobileNumber=${mobile_No}
    ...    source=${CAM_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_initiate    /api/v1/fetch/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${CAMS_referFetchID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console     TC_12: CAMS ReferFetchID: ${CAMS_referFetchID}
    RETURN    ${CAMS_referFetchID}

TC_13 CAMS Fetch Validate OTP
    [Arguments]    ${CAMS_referFetchID}
    Create Session    CAMS_validate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_referFetchID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_validate    /api/v1/fetch/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_13: ${json["status"]["message"]}

TC_14 Eligible Holdings CAMS
    [Arguments]    ${loanApp_No}    ${CAMS_referFetchID}
    Create Session    CAMS_Eligible_holding    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${CAM_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Eligible_holding    /api/v1/fetch/mutual-funds/eligible-holdings
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${eligibleFunds}=    Get From Dictionary    ${json['data']['CAMS']}    eligibleFunds
    ${CAMS_funds}=       Get From List    ${eligibleFunds}    0
    Log To Console     TC_14: ${json["status"]["message"]}
    RETURN    ${CAMS_funds}

TC_15 Pledge Initiate CAMS
    [Arguments]    ${loanApp_No}    ${CAMS_referFetchID}    ${CAMS_funds}
    Create Session    CAMS_Pledge_initiate    url=${PARTNER_CLIENT_URL}    verify=true
    &{funds}=    Create Dictionary
    ...    modeOfHolding=${modeOfHolding}
    ...    rtaName=${CAMS_funds['rtaName']}
    ...    amcCode=${CAMS_funds['amcCode']}
    ...    amcName=${CAMS_funds['amcName']}
    ...    folio=${CAMS_funds['folioNumber']}
    ...    schemeCode=${CAMS_funds['schemeCode']}
    ...    schemeName=${CAMS_funds['schemeName']}
    ...    isin=${CAMS_funds['isin']}
    ...    schemeType=${CAMS_funds['assetSubType']}
    ...    schemeCategory=${schemeCategory}
    ...    lienUnit=${lienUnit}
    @{optedSchemeDetails}=    Create List    ${funds}
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    fetchRefId=${CAMS_referFetchID}
    ...    source=${CAM_source}
    ...    funds=${optedSchemeDetails}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Pledge_initiate    /api/v1/pledge/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${CAMS_pledgeRefID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console     TC_15: CAMS_PledgeRefID: ${CAMS_pledgeRefID}, ${json["status"]["message"]}
    RETURN    ${CAMS_pledgeRefID}

TC_16 Pledge Validate CAMS
    [Arguments]    ${CAMS_pledgeRefID}
    Create Session    CAMS_Pledge_validate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_pledgeRefID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Pledge_validate    /api/v1/pledge/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_16: ${json["status"]["message"]}

# ─── KFINTECH ─────────────────────────────────────────────────────────────────
TC_17 Kfintech Fetch Initiate
    [Arguments]    ${loanApp_No}    ${PAN_Number}    ${mobile_No}
    Create Session    Kfintech_initiate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    pan=${PAN_Number}
    ...    mobileNumber=${mobile_No}
    ...    source=${Kfintech_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Kfintech_initiate    /api/v1/fetch/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${KFin_referFetchID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console     TC_17: KFin ReferFetchID: ${KFin_referFetchID}
    RETURN    ${KFin_referFetchID}

TC_18 Kfintech Fetch Validate OTP
    [Arguments]    ${KFin_referFetchID}
    Create Session    Kfintech_validate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${KFin_referFetchID}
    ...    otp=123456
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Kfintech_validate    /api/v1/fetch/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_18: ${json["status"]["message"]}

TC_19 Eligible Holdings KFINTECH
    [Arguments]    ${loanApp_No}    ${KFin_referFetchID}
    Create Session    KFIN_Eligible_holding    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${Kfintech_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    KFIN_Eligible_holding    /api/v1/fetch/mutual-funds/eligible-holdings
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${KFIN_eligibleFunds}=    Get From Dictionary    ${json['data']['KFINTECH']}    eligibleFunds
    ${KFIN_funds}=    Get From List    ${KFIN_eligibleFunds}    0
    Log To Console     TC_19: ${json["status"]["message"]}
    RETURN    ${KFIN_funds}

TC_20 Pledge Initiate KFINTECH
    [Arguments]    ${loanApp_No}    ${KFin_referFetchID}    ${KFIN_funds}
    Create Session    KFIN_Pledge_initiate    url=${PARTNER_CLIENT_URL}    verify=true
    &{funds}=    Create Dictionary
    ...    modeOfHolding=${modeOfHolding}
    ...    rtaName=${KFIN_funds['rtaName']}
    ...    amcCode=${KFIN_funds['amcCode']}
    ...    amcName=null
    ...    folio=${KFIN_funds['folioNumber']}
    ...    schemeCode=${KFIN_funds['schemeCode']}
    ...    schemeName=${KFIN_funds['schemeName']}
    ...    isin=${KFIN_funds['isin']}
    ...    schemeType=${KFIN_funds['assetSubType']}
    ...    schemeCategory=${schemeCategory}
    ...    lienUnit=${lienUnit}
    @{optedSchemeDetails}=    Create List    ${funds}
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    fetchRefId=${KFin_referFetchID}
    ...    source=${Kfintech_source}
    ...    funds=${optedSchemeDetails}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    KFIN_Pledge_initiate    /api/v1/pledge/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${KFIN_pledgeRefID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console     TC_20: KFIN_PledgeRefID: ${KFIN_pledgeRefID}, ${json["status"]["message"]}
    RETURN    ${KFIN_pledgeRefID}

TC_21 Pledge Validate KFINTECH
    [Arguments]    ${KFIN_pledgeRefID}
    Create Session    KFIN_Pledge_validate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${KFIN_pledgeRefID}
    ...    otp=123456
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    KFIN_Pledge_validate    /api/v1/pledge/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_21: ${json["status"]["message"]}

# ─── Post-Pledge ──────────────────────────────────────────────────────────────
TC_22 Eligibility Check
    [Arguments]    ${loanApp_No}
    Create Session    eligibility_check    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    eligibility_check    /api/v1/loan-application/eligibility_check
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    ELIGIBILITY_CHECK
    Should Be Equal    ${json["data"]["platformStatus"]}    COMPLETED
    Should Be Equal    ${json["data"]["externalStatus"]}    ELIGIBILITY_CHECK_COMPLETED
    Log To Console     TC_22: ${json["status"]["message"]}

TC_23 Beneficiary Add
    [Arguments]    ${loanApp_No}
    Create Session    Beneficiary_add    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    bankAccountNumber=${BANK_ACCOUNT_NO}
    ...    ifscCode=${BANK_IFSC}
    ...    bankName=${BANK_NAME}
    ...    bankAccountType=${BANK_ACCOUNT_TYPE}
    ...    accountHolderName=${ACCOUNT_HOLDER_NAME}
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    Beneficiary_add    /api/v1/bank/init
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_23: ${json["status"]["message"]}

TC_24 DigiSign
    [Arguments]    ${loanApp_No}
    Create Session    DigiSign    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    templateType=${TEMPLATE_TYPE}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    DigiSign    /api/v1/digisign/initiate
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_24: ${json["status"]["message"]}

TC_25 DigiSign Status
    [Arguments]    ${loanApp_No}
    Create Session    DigiSign_status    url=${PARTNER_CLIENT_URL}    verify=true
    ${params}=      Create Dictionary    loanApplicationNo=${loanApp_No}     templateType=${TEMPLATE_TYPE}
    ${headers}=     Build Get Headers
    ${response}=    GET On Session    DigiSign_status    /api/v1/digisign/status     headers=${headers}     params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    # Should Be Equal    ${json["status"]["code"]}    ${expected_code}
    Log To Console     TC_25: ${json["status"]["message"]}

TC_26 mandate initiate
    [Arguments]    ${loanApp_No}
    Create Session    mandate_initiate    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary     loanApplicationNo=${loanApp_No}
    ...                bankAccountNumber=${BANK_ACCOUNT_NO}
    ...                redirectionURL=${REDIRECT_URL}
    ...                ifscCode=${BANK_IFSC}
    ...                bankName=${BANK_NAME}
    ...                bankAccountType=${BANK_ACCOUNT_TYPE}
    ...                accountHolderName=${ACCOUNT_HOLDER_NAME}
    ...                authMode=${1}
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    mandate_initiate    /api/v1/bank/mandate/initiate
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console     TC_26: ${json["status"]["message"]}

TC_27 mandate status
    [Arguments]    ${loanApp_No}
    Create Session    mandate_status    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=       Create Dictionary    loanApplicationNo=${loanApp_No}
    ${headers}=     Build Headers    ${body}
    ${response}=    POST On Session    mandate_status    /api/v1/bank/mandate/status     json=${body}     headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    # Should Be Equal    ${json["status"]["code"]}    ${expected_code}
    Log To Console     TC_27: ${json["status"]["message"]}

TC_28 Video KYC
    [Arguments]    ${loanApp_No}
    Create Session    video_kyc    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    video_kyc    /api/v1/vkyc/initiate
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console     TC_28: ${json["status"]["message"]}

TC_29 VKYC Check Status
    [Arguments]    ${loanApp_No}
    Create Session    vkyc_status    url=${PARTNER_CLIENT_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    vkyc_status    /api/v1/vkyc/check-status
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    # Should Be Equal    ${json["status"]["code"]}    ${expected_code}
    Log To Console     TC_29: VKYC Status: ${json["data"]["externalStatus"]}, ${json["status"]["message"]}

TC_30 Logout
    [Documentation]    Only called in LOGIN mode — no logout needed for HMAC.
    Create Session    logout    url=${PARTNER_CLIENT_URL}    verify=true
    ${headers}=     Build Get Headers
    ${response}=    GET On Session    logout    /api/v1/auth/logout    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_30: Logout — ${json["status"]["message"]}
