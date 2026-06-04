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

TC_04 getCustomer_details
    [Arguments]        ${platform_custId}
    [Documentation]    Get Customer Details
    Create Session     get_CustomerDetails    url=${QA_URL}     verify=true

    ${params}=         Create Dictionary    platformCustomerId=${platform_custId}
    ${headers}=        Build Get Headers
    ${response}        GET On Session       get_CustomerDetails     /api/v1/customer     headers=${headers}     params=${params}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}             Get From List          ${status_msg}     0
    ${name}            Get Value From Json    ${json_data}    data[0].firstName
    ${cust_name}       Get From List          ${name}     0
    ${pan}             Get Value From Json    ${json_data}    data[0].pan
    ${cust_pan}        Get From List          ${pan}           0
    Log To Console     TC_04 getCustomer_details: ${msg}, customerName:${cust_name}, customerPan:${cust_pan}

TC_05 getProduct
    [Documentation]    Get product details
    Create Session     getProduct_details     url=${QA_URL}     verify=true

    ${headers}=        Build Get Headers
    ${response}        GET On Session       getProduct_details     /api/v1/product     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_code}     Get Value From Json    ${json_data}    status.http_status
    ${http_status}     Get From List          ${status_code}    0
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}             Get From List          ${status_msg}     0
    Log To Console     TC_05 getProduct: ${msg}

    RETURN     ${OD_productCode}

TC_06 Create Loan Application
    [Arguments]       ${PAN_Number}    ${mobile_No}
    Create Session    create_LoanApp    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    pan=${PAN_Number}
    ...    productCode=${OD_productCode}
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
    Log To Console     TC_06: ${json["status"]["message"]}, LoanApp_No: ${loanApp_No}
    RETURN    ${loanApp_No}    ${productType}

TC_07 emailInitiate
    [Arguments]    ${loanApp_No}
    Create Session    email_init    url=${QA_URL}    verify=true
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
    Log To Console     TC_07 emailInitiate: ${json["status"]["message"]}, RefID: ${email_referId}
    RETURN    ${email_referId}

TC_08 emailValidate
    [Arguments]    ${email_referId}
    Create Session    email_validate    url=${QA_URL}    verify=true
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
    Log To Console     TC_08 emailValidate: ${json["status"]["message"]}

TC getCodeValue
    [Documentation]    Get Code Value Details
    Create Session     get_CodeValue     url=${QA_URL}     verify=true

    ${params}=         Create Dictionary    codeId=${codeValue_Id}
    ${headers}=        Build Get Headers

    ${response}        GET On Session     get_CodeValue     /api/v1/code-value     headers=${headers}     params=${params}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}             Get From List          ${status_msg}     0
    Log To Console     TC_09 getCodeValue: ${msg}

TC_09 updateLoanApplication
    [Arguments]    ${loanApp_No}
    Create Session    update_loan    url=${QA_URL}    verify=true
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
    Log To Console     TC_09: ${json["status"]["message"]}

TC_10 getCust_BankDetail
    [Arguments]        ${platform_custId}
    [Documentation]    Get Customer Bank Details
    Create Session     get_CustBankDetails     url=${QA_URL}     verify=true

    ${headers}=        Build Get Headers
    ${response}        GET On Session       get_CustBankDetails     /api/v1/customer/bankAccounts/${platform_custId}     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}     status.message
    ${msg}             Get From List          ${status_msg}     0
    ${AccDetail}       Get Value From Json    ${json_data}     data.bankDetails[0].bankAccountNumber
    ${bankAccount}     Get From List          ${AccDetail}      0
    ${ifscCode}        Get Value From Json    ${json_data}     data.bankDetails[0].ifscCode
    ${ifsc}            Get From List          ${ifscCode}       0
    ${bank}            Get Value From Json    ${json_data}     data.bankDetails[0].bankName
    ${bankName}        Get From List          ${bank}           0
    ${AccountType}     Get Value From Json    ${json_data}     data.bankDetails[0].bankAccountType
    ${bankAccountType}    Get From List       ${AccountType}    0
    ${HolderName}      Get Value From Json    ${json_data}     data.bankDetails[0].accountHolderName
    ${accountHolderName}     Get From List    ${HolderName}     0

    Log To Console     TC_10 Get Customer Bank Details: ${msg}
    RETURN     ${bankAccount}     ${ifsc}     ${bankName}     ${bankAccountType}     ${accountHolderName}

TC_11 create_BankInt
    [Arguments]           ${loanApp_No}     ${bankAccount}     ${ifsc}     ${bankName}     ${bankAccountType}     ${accountHolderName}
    [Documentation]       Creating Bank details using CustID
    Create Session        Bank_Init     url=${QA_URL}     verify=true

    ${data}            Create Dictionary
    ...                loanApplicationNo=${loanApp_No}
    ...                bankAccountNumber=${bankAccount}
    ...                ifscCode=${ifsc}
    ...                bankName=${bankName}
    ...                bankAccountType=${bankAccountType}
    ...                accountHolderName=${accountHolderName}
    ${headers}=        Build Headers    ${data}

    ${response}        POST On Session       Bank_Init     /api/v1/bank/init     json=${data}     headers=${headers}
    ${status_code}=    Convert To String     ${response.status_code}
    Should Be Equal    ${status_code}        ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}     Get From List    ${status_msg}         0
    Log To Console     TC_11: ${msg}

TC_12 CAMS_Fetch_initiate
    [Arguments]       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
    Create Session    CAMS_initiate    url=${QA_URL}    verify=true
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

TC_13 CAMS_Fetch_Validate OTP
    [Arguments]    ${CAMS_referFetchID}
    Create Session    CAMS_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_referFetchID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_validate    /api/v1/fetch/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_13: ${json["status"]["message"]}

TC_14 Eligible Holdings_CAMS
    [Arguments]    ${loanApp_No}    ${CAMS_referFetchID}
    Create Session    CAMS_Eligible_holding    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${CAM_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Eligible_holding    /api/v1/fetch/mutual-funds/eligible-holdings
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    ${eligibleFunds}=    Get From Dictionary    ${json['data']['CAMS']}    eligibleFunds
    ${eligibleFunds}=    Evaluate    __import__('json').loads($eligibleFunds) if isinstance($eligibleFunds, str) else $eligibleFunds
    ${CAMS_funds}=    Get From List    ${eligibleFunds}    0
    ${CAMS_funds}=    Evaluate    __import__('json').loads($CAMS_funds) if isinstance($CAMS_funds, str) else $CAMS_funds
    Log To Console    TC_14: ${json["status"]["message"]}
    RETURN    ${CAMS_funds}

TC_15 Opt_MF_Using_Index_CAMS
    [Arguments]     ${CAMS_funds}     ${CAMS_referFetchID}     ${loanApp_No}
    [Documentation]     Fetch_opted - (CAMS)
    Create Session      CAMS_Opt       url=${QA_URL}     verify=true

    ${units}              Convert To Integer    ${CAMS_funds['units']}
    ${opted_units}=       Convert To Integer    ${CAMS_funds['units']}

    &{scheme}=    Create Dictionary
    ...    rtaName=${CAMS_funds['rtaName']}
    ...    amcCode=${CAMS_funds['amcCode']}
    ...    schemeCode=${CAMS_funds['schemeCode']}
    ...    isin=${CAMS_funds['isin']}
    ...    folioNumber=${CAMS_funds['folioNumber']}
    ...    units=${units}
    ...    optedUnits=${opted_units}

    @{optedSchemeDetails}=    Create List    ${scheme}

    &{payload}=    Create Dictionary
    ...    fetchId=${CAMS_referFetchID}
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${CAM_source}
    ...    productCode=${OD_productCode}
    ...    optedSchemeDetails=${optedSchemeDetails}
    ${headers}=    Build Headers    ${payload}

    ${response}=       POST On Session      CAMS_Opt    /api/v1/fetch/mutual-funds/opted    json=${payload}    headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}             Get From List          ${status_msg}     0
    Log To Console     TC_15: ${msg}

TC_16 Pledge Initiate CAMS
    [Arguments]    ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_No}
    Create Session    CAMS_Pledge_initiate    url=${QA_URL}    verify=true
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
    Log To Console     TC_16: CAMS_PledgeRefID: ${CAMS_pledgeRefID}, ${json["status"]["message"]}
    RETURN    ${CAMS_pledgeRefID}

TC_17 Pledge Validate CAMS
    [Arguments]    ${CAMS_pledgeRefID}
    Create Session    CAMS_Pledge_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_pledgeRefID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Pledge_validate    /api/v1/pledge/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${json}=    Set Variable    ${response.json()}
    Log To Console     TC_17: ${json["status"]["message"]}
