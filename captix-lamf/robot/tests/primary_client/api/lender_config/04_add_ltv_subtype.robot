*** Settings ***
Resource     ../../../../resources/common.resource
Resource     01_add_lender.robot
Resource     03_add_product_asset.robot

*** Variables ***
${lenderId}=            3
${lenderName}=          SAMPLE_LENDER
${codeValueId}          3
${holdingName}=         Equity
# ${maxLoanAmt}=          500000
${assetSubType}=        1
${ltv}=                 75.50
${totalAssetSubLim}=    5000000.00   

*** Keywords ***
Build_Parameter
    [Arguments]      ${asset_SubTypeLimit_applicable}    ${lenderId}     ${lenderName}        
    # 1. Start with the base mandatory fields
    ${lender_detail}     Create Dictionary     id=${lenderId}     lenderName=${lenderName}
    ${holding_Format}    Create Dictionary     codeValueId=${codeValueId}      name=${holdingName}
    &{PAYLOAD}    Create Dictionary
    ...           lender=${lender_detail}
    ...           assetType=${assetType}
    ...           assetSubType=${assetSubType}
    ...           holdingFormat=${holding_Format}
    # ...           maximumLoanAmount=${maxLoanAmt}
    ...           ltv=${ltv}
    ...           totalAssetSubTypeLimit=${totalAssetSubLim} 
    ...           status=True 

    # 2. Convert the input argument to a boolean value for comparison
    ${AssetSubType_APPLICABLE}=      Convert To Boolean    ${asset_SubTypeLimit_applicable}
    
    # 3. Add conditional fields based on the flag
    Set To Dictionary    ${PAYLOAD}    assetSubTypeLimitApplicable=${AssetSubType_APPLICABLE}
    
    # 4. Conditional Check for totalAssetSubTypeLimit Limit
    IF  ${AssetSubType_APPLICABLE} == ${True}    
        Set To Dictionary    ${PAYLOAD}    totalAssetSubTypeLimit=${totalAssetSubLim}
        ELSE
        Remove From Dictionary   ${PAYLOAD}    totalAssetSubTypeLimit    # ELSE: totalAssetSubTypeLimit is omitted
    END

    RETURN    ${PAYLOAD} 

TC04_LtvAssetSubType_Positive
    [Documentation]    This keyword sets up the environment for LTV-product onboarding tests.
    [Arguments]        ${asset_SubTypeLimit_applicable}    ${lenderId}     ${lenderName}    
    Create Session      add_ltvSubType     ${PRIMARY_CLIENT_URL}     verify=true
    ${REQUEST_BODY}=    Build_Parameter    ${asset_SubTypeLimit_applicable}    ${lenderId}     ${lenderName}             
    ${headers}=         Create Dictionary    Content-Type=application/json
    
    # Log the body to verify the conditional fields were included/excluded
    Log Dictionary    ${REQUEST_BODY}
    
    # B. Execute the POST on Session
    ${RESPONSE}=    POST On Session  add_ltvSubType    /api/v1/ltv-asset    json=${REQUEST_BODY}    headers=${headers}    expected_status=${expected_code}    
    
    # D. Optional: Add assertion to ensure correct keys were sent/returned
    Run Keyword If    '${asset_SubTypeLimit_applicable}' == 'True'
    ...    Dictionary Should Contain Key    ${REQUEST_BODY}    totalAssetSubTypeLimit
    Run Keyword If    '${asset_SubTypeLimit_applicable}' == 'False'
    ...    Dictionary Should Not Contain Key    ${REQUEST_BODY}    totalAssetSubTypeLimit
    
    ${json_data}          Convert String To Json    ${response.content}
    ${id}                 Get Value From Json    ${json_data}    status.message
    ${ltvSubType_id}      Get From List         ${id}             0
    Log To Console        Ltv respose msg: ${ltvSubType_id}

# *** Test Cases ***
# TC04_ProductAsset Onboarding_Positive
#     ${lender_id}    ${lenderName}=    TC01_Lender Onboarding_Positive
#     TC04_LtvAssetSubType_Positive     True      ${lenderId}     ${lenderName}