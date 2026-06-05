*** Settings ***
Documentation     PRIMARY_CLIENT Term Loan (TL) flow keywords. Auth-mode agnostic — headers built via BuildHeader.
Resource     ../common.resource
Resource     ../build_header.resource
Library      ../../libraries/MongoManager.py     env=qa

*** Keywords ***
TL_Dedupe
    [Arguments]    ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    [Documentation]    Verify the Customer is already present or not.
    ...                Builds request body based on suite-level ${DEDUPE_BY}:
    ...                PAN → {"pan": ...}; MOBILE → {"mobileNumber": ...}; LENDER_CUST_ID → {"lenderCustomerId": ...}
    Create Session    dedupe_check    url=${QA_URL}    verify=true
    IF    '${DEDUPE_BY}' == 'PAN'
        ${body}=    Create Dictionary    pan=${PAN_Number}
    ELSE IF    '${DEDUPE_BY}' == 'MOBILE'
        ${body}=    Create Dictionary    mobileNumber=${mobile_No}
    ELSE IF    '${DEDUPE_BY}' == 'LENDER_CUST_ID'
        ${body}=    Create Dictionary    lenderCustomerId=${lender_cust_id}
    ELSE
        Fail    Invalid DEDUPE_BY '${DEDUPE_BY}'. Use PAN, MOBILE, or LENDER_CUST_ID.
    END
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    dedupe_check    /api/v1/dedupe-check
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${msg}=    Set Variable    ${json["status"]["message"]}

    IF    'An active loan application already exists' in "${msg}"
        ${platform_custId}=    Set Variable    ${json["data"]["platformCustomerId"]}
        ${loanApp_No}=    Set Variable    ${json["data"]["loanApplicationNo"]}
        ${prodType}=    Set Variable    ${json["data"]["productType"]}
        Log To Console    platformCustomerId: ${platform_custId}, loanAppNo: ${loanApp_No}, productType: ${prodType}

        ${params}=    Create Dictionary    loanApplicationNo=${loanApp_No}
        ${headers}=    Build Get Headers
        ${response}=    GET On Session    dedupe_check    /api/v1/workflow/workflow-details    headers=${headers}    params=${params}
        ${wf_json}=    Set Variable    ${response.json()}
        Fail    msg=${wf_json["status"]["message"]}
    END

    Should Be Equal    ${json["status"]["code"]}    OTP_INITIATED
    ${referenceId}=    Set Variable    ${json["data"]["referenceId"]}
    Should Not Be Empty    ${referenceId}
    Log To Console    TL_02 Dedupe: ${msg}
    RETURN    ${referenceId}

TL_validate_OTP
    [Arguments]    ${referenceId}
    [Documentation]    Validating OTP
    Create Session    validate_otp    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${referenceId}
    ...    otp=${DEDUPE_OTP}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    validate_otp    /api/v1/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    OTP_VALIDATED
    ${platform_custId}=    Set Variable    ${json["data"]["platformCustomerId"]}
    Should Not Be Empty    ${platform_custId}
    Log To Console    TL_03: ${json["status"]["message"]}, platformCustomerId: ${platform_custId}
    RETURN    ${platform_custId}

TL_getCustomer_details
    [Arguments]    ${platform_custId}
    [Documentation]    Get Customer Details
    Create Session    get_CustomerDetails    url=${QA_URL}    verify=true
    ${params}=    Create Dictionary    platformCustomerId=${platform_custId}
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    get_CustomerDetails    /api/v1/customer    headers=${headers}    params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${cust_name}=    Set Variable    ${json["data"][0]["firstName"]}
    ${cust_pan}=    Set Variable    ${json["data"][0]["pan"]}
    Log To Console    TL_04: ${json["status"]["message"]}, customerName:${cust_name}, customerPan:${cust_pan}

TL_getProduct
    [Documentation]    Get product details
    Create Session    getProduct_details    url=${QA_URL}    verify=true
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    getProduct_details    /api/v1/product    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_05: ${json["status"]["message"]}
    RETURN    ${TL_productCode}

TL_loanApplication_Init
    [Arguments]    ${TL_productCode}    ${PAN_Number}    ${mobile_No}
    [Documentation]    Loan initiate
    Create Session    LoanApp_init    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    pan=${PAN_Number}
    ...    productCode=${TL_productCode}
    ...    mobileNumber=${mobile_No}
    ...    email=${EMAIL}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    LoanApp_init    /api/v1/loan-application/apply
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Should Be Equal    ${json["status"]["code"]}    LOAN_APPLICATION_CREATED

    ${cust_id}=    MongoManager.Get Customer Id By Pan    ${PAN_Number}
    ${loanApp_No}=    MongoManager.Get LoanApp No By CustId    ${cust_id}
    ${loanApp_Id}=    MongoManager.Get LoanAppId By LoanNumber    ${loanApp_No}
    Should Not Be Empty    ${loanApp_No}

    Set Suite Variable    ${loanApp_No}
    Set Suite Variable    ${loanApp_Id}
    Set Suite Variable    ${cust_id}

    Log To Console    TL_06: ${json["status"]["message"]}
    Log To Console    customer_Id: ${cust_id}, loanApp_No: ${loanApp_No}, loanApp_Id: ${loanApp_Id}
    RETURN    ${loanApp_No}    ${loanApp_Id}    ${cust_id}

TL_emailInitiate
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

TL_emailValidate
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

TL_getCodeValue
    [Documentation]    Get Code Value Details
    Create Session    get_CodeValue    url=${QA_URL}    verify=true
    ${params}=    Create Dictionary    codeId=${codeValue_Id}
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    get_CodeValue    /api/v1/code-value    headers=${headers}    params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL getCodeValue: ${json["status"]["message"]}

TL_updateLoanApp
    [Arguments]    ${loanApp_No}
    [Documentation]    updating loan application
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
    Log To Console    TL_09 updateLoanApplication: ${json["status"]["message"]}

TL_getCust_BankDetail
    [Arguments]    ${platform_custId}
    [Documentation]    Get Customer Bank Details
    Create Session    get_CustBankDetails    url=${QA_URL}    verify=true
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    get_CustBankDetails    /api/v1/customer/bankAccounts/${platform_custId}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${bankAccount}=    Set Variable    ${json["data"]["bankDetails"][0]["bankAccountNumber"]}
    ${ifsc}=    Set Variable    ${json["data"]["bankDetails"][0]["ifscCode"]}
    ${bankName}=    Set Variable    ${json["data"]["bankDetails"][0]["bankName"]}
    ${bankAccountType}=    Set Variable    ${json["data"]["bankDetails"][0]["bankAccountType"]}
    ${accountHolderName}=    Set Variable    ${json["data"]["bankDetails"][0]["accountHolderName"]}
    Log To Console    TL_10 Get Customer Bank Details: ${json["status"]["message"]}
    RETURN    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}

TL_create_BankInt
    [Arguments]    ${loanApp_No}    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}
    [Documentation]    Creating Bank details using CustID
    Create Session    Bank_Init    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    bankAccountNumber=${bankAccount}
    ...    ifscCode=${ifsc}
    ...    bankName=${bankName}
    ...    bankAccountType=${bankAccountType}
    ...    accountHolderName=${accountHolderName}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Bank_Init    /api/v1/bank/init
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_11: ${json["status"]["message"]}

TL_CAMS_Fetch_initiate
    [Arguments]    ${TL_productCode}    ${loanApp_No}    ${PAN_Number}    ${mobile_No}
    Create Session    CAMS_initiate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    pan=${PAN_Number}
    ...    mobileNumber=${mobile_No}
    ...    source=${CAM_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_initiate    /api/v1/fetch/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${CAMS_referFetchID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console    TL_12: CAMS ReferFetchID: ${CAMS_referFetchID}
    RETURN    ${CAMS_referFetchID}

TL_CAMS_Fetch_Validate OTP
    [Arguments]    ${CAMS_referFetchID}
    Create Session    CAMS_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_referFetchID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_validate    /api/v1/fetch/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_13: ${json["status"]["message"]}

TL_Eligible Holdings_CAMS
    [Arguments]    ${loanApp_No}    ${CAMS_referFetchID}
    Create Session    CAMS_Eligible_holding    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${CAM_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Eligible_holding    /api/v1/fetch/mutual-funds/eligible-holdings
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${eligibleFunds}=    Get From Dictionary    ${json['data']['CAMS']}    eligibleFunds
    ${eligibleFunds}=    Evaluate    __import__('json').loads($eligibleFunds) if isinstance($eligibleFunds, str) else $eligibleFunds
    ${CAMS_funds}=    Get From List    ${eligibleFunds}    0
    ${CAMS_funds}=    Evaluate    __import__('json').loads($CAMS_funds) if isinstance($CAMS_funds, str) else $CAMS_funds
    Log To Console    TL_14: ${json["status"]["message"]}
    RETURN    ${CAMS_funds}

TL_Opt_MF_Using_Index_CAMS
    [Arguments]    ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_Id}
    [Documentation]    Fetch_opted - (CAMS)
    Create Session    CAMS_Opt    url=${QA_URL}    verify=true

    ${units}=    Convert To Integer    ${CAMS_funds['units']}
    ${opted_units}=    Convert To Integer    ${CAMS_funds['units']}

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
    ...    loanApplicationNo=${loanApp_Id}
    ...    source=${CAM_source}
    ...    productCode=${TL_productCode}
    ...    optedSchemeDetails=${optedSchemeDetails}
    ${headers}=    Build Headers    ${payload}
    ${response}=    POST On Session    CAMS_Opt    /api/v1/fetch/mutual-funds/opted
    ...    json=${payload}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_15: ${json["status"]["message"]}

TL_PledgeInitiate_CAMS
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
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${CAMS_pledgeRefID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console    TL_16: CAMS_PledgeRefID: ${CAMS_pledgeRefID}, ${json["status"]["message"]}
    RETURN    ${CAMS_pledgeRefID}

TL_PledgeValidate_CAMS
    [Arguments]    ${CAMS_pledgeRefID}
    Create Session    CAMS_Pledge_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${CAMS_pledgeRefID}
    ...    otp=12345
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    CAMS_Pledge_validate    /api/v1/pledge/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_17: ${json["status"]["message"]}

TL_Kfintech_Fetch_initiate
    [Arguments]    ${TL_productCode}    ${loanApp_No}    ${PAN_Number}    ${mobile_No}
    Create Session    Kfintech_initiate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    pan=${PAN_Number}
    ...    mobileNumber=${mobile_No}
    ...    source=${Kfintech_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Kfintech_initiate    /api/v1/fetch/mutual-funds/initiate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${KFin_referFetchID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console    TL_18: KFin ReferFetchID: ${KFin_referFetchID}
    RETURN    ${KFin_referFetchID}

TL_Kfintech_Fetch_Validate OTP
    [Arguments]    ${KFin_referFetchID}
    Create Session    Kfintech_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${KFin_referFetchID}
    ...    otp=123456
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Kfintech_validate    /api/v1/fetch/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_19: ${json["status"]["message"]}

TL_Eligible Holdings_KFINTECH
    [Arguments]    ${loanApp_No}    ${KFin_referFetchID}
    Create Session    KFIN_Eligible_holding    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    source=${Kfintech_source}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    KFIN_Eligible_holding    /api/v1/fetch/mutual-funds/eligible-holdings
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${KFIN_eligibleFunds}=    Get From Dictionary    ${json['data']['KFINTECH']}    eligibleFunds
    ${KFIN_eligibleFunds}=    Evaluate    __import__('json').loads($KFIN_eligibleFunds) if isinstance($KFIN_eligibleFunds, str) else $KFIN_eligibleFunds
    ${KFIN_funds}=    Get From List    ${KFIN_eligibleFunds}    0
    ${KFIN_funds}=    Evaluate    __import__('json').loads($KFIN_funds) if isinstance($KFIN_funds, str) else $KFIN_funds
    Log To Console    TL_20: ${json["status"]["message"]}
    RETURN    ${KFIN_funds}

TL_Opt_MF_Using_Index_KFINTECH
    [Arguments]    ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_Id}
    [Documentation]    Fetch_opted - (KFINTECH)
    Create Session    KFIN_Opt    url=${QA_URL}    verify=true

    ${units}=    Convert To Integer    ${KFIN_funds['units']}
    ${opted_units}=    Convert To Integer    ${KFIN_funds['units']}

    &{scheme}=    Create Dictionary
    ...    rtaName=${KFIN_funds['rtaName']}
    ...    amcCode=${KFIN_funds['amcCode']}
    ...    schemeCode=${KFIN_funds['schemeCode']}
    ...    isin=${KFIN_funds['isin']}
    ...    folioNumber=${KFIN_funds['folioNumber']}
    ...    units=${units}
    ...    optedUnits=${opted_units}

    @{optedSchemeDetails}=    Create List    ${scheme}

    &{payload}=    Create Dictionary
    ...    fetchId=${KFin_referFetchID}
    ...    loanApplicationNo=${loanApp_Id}
    ...    source=${Kfintech_source}
    ...    productCode=${TL_productCode}
    ...    optedSchemeDetails=${optedSchemeDetails}
    ${headers}=    Build Headers    ${payload}
    ${response}=    POST On Session    KFIN_Opt    /api/v1/fetch/mutual-funds/opted
    ...    json=${payload}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_21: ${json["status"]["message"]}

TL_PledgeInitiate_KFINTECH
    [Arguments]    ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_No}
    Create Session    KFIN_Pledge_initiate    url=${QA_URL}    verify=true
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
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    ${KFIN_pledgeRefID}=    Set Variable    ${json["data"]["referenceId"]}
    Log To Console    TL_22: KFIN_PledgeRefID: ${KFIN_pledgeRefID}, ${json["status"]["message"]}
    RETURN    ${KFIN_pledgeRefID}

TL_PledgeValidate_KFINTECH
    [Arguments]    ${KFIN_pledgeRefID}
    Create Session    KFIN_Pledge_validate    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    referenceId=${KFIN_pledgeRefID}
    ...    otp=123456
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    KFIN_Pledge_validate    /api/v1/pledge/mutual-funds/validate-otp
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_23: ${json["status"]["message"]}

TL_Pledge_lienStatus
    [Arguments]    ${KFin_referFetchID}
    [Documentation]    Pledge_lienStatus
    Create Session    Pledge_lienStatus    url=${QA_URL}    verify=true
    ${params}=    Create Dictionary    pledgeRefId=${KFin_referFetchID}
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    Pledge_lienStatus    /api/v1/pledge/mutual-funds/lien-status    headers=${headers}    params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL Pledge_lienStatus: ${json["status"]["message"]}

TL_updateLoanApp_InterestTenure
    [Arguments]    ${loanApp_No}
    [Documentation]    updating loan application — interest & tenure
    Create Session    LoanApp_update    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    interestRate=${15}
    ...    tenure=${12}
    ${headers}=    Build Headers    ${body}
    ${response}=    PUT On Session    LoanApp_update    /api/v1/loan-application/update
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_24: ${json["status"]["message"]}

TL_DigiSign_KFS
    [Arguments]    ${loanApp_No}
    [Documentation]    DigiSign_KFS
    Create Session    DigiSign_KFS    url=${QA_URL}    verify=true
    ${params}=    Create Dictionary    loanApplicationNo=${loanApp_No}    templateType=KFS_AND_SANCTION
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    DigiSign_KFS    /api/v1/digisign/generate-document    headers=${headers}    params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    DigiSign_KFS: ${json["status"]["message"]}

TL_DigiSign
    [Arguments]    ${loanApp_No}
    [Documentation]    Post Digi_Sign
    Create Session    DigiSign    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    templateType=KFS_AND_SANCTION
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    DigiSign    /api/v1/digisign/initiate
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_25: ${json["status"]["message"]}

TL_DigiSign_Status
    [Arguments]    ${loanApp_No}
    [Documentation]    DigiSign_Status
    Create Session    DigiSign_status    url=${QA_URL}    verify=true
    ${params}=    Create Dictionary    loanApplicationNo=${loanApp_No}    templateType=KFS_AND_SANCTION
    ${headers}=    Build Get Headers
    ${response}=    GET On Session    DigiSign_status    /api/v1/digisign/status    headers=${headers}    params=${params}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_26: ${json["status"]["message"]}

TL_LoanSubmit
    [Arguments]    ${loanApp_No}
    [Documentation]    Loan Submission
    Create Session    Loan_Submit    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Loan_Submit    /api/v1/loan/submit
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_27 LoanSubmit: ${json["status"]["message"]}

TL_mandateInt
    [Arguments]    ${loanApp_No}    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}
    [Documentation]    E-Mandate initiate
    Create Session    Mandate_Init    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary
    ...    loanApplicationNo=${loanApp_No}
    ...    bankAccountNumber=${bankAccount}
    ...    redirectionURL=https://www.example.com
    ...    ifscCode=${ifsc}
    ...    bankName=${bankName}
    ...    bankAccountType=${bankAccountType}
    ...    accountHolderName=${accountHolderName}
    ...    authMode=${1}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Mandate_Init    /api/v1/bank/mandate/initiate
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_28: ${json["status"]["message"]}

TL_mandateStatus
    [Arguments]    ${loanApp_No}
    [Documentation]    E-Mandate status
    Create Session    Mandate_Status    url=${QA_URL}    verify=true
    ${body}=    Create Dictionary    loanApplicationNo=${loanApp_No}
    ${headers}=    Build Headers    ${body}
    ${response}=    POST On Session    Mandate_Status    /api/v1/bank/mandate/status
    ...    json=${body}    headers=${headers}
    ${json}=    Set Variable    ${response.json()}
    Should Be Equal As Integers    ${response.status_code}    ${expected_code}
    Log To Console    TL_29: ${json["status"]["message"]}
