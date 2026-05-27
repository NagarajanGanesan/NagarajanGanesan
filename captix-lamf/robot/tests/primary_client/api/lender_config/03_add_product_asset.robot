*** Settings ***
Resource     ../../../../resources/common.resource
Resource     01_add_lender.robot

*** Variables ***
${lenderId}=        3
${lenderName}=      SAMPLE_LENDER
${productType}=     1
${assetType}=       1
${minLoanAmt}=      100000.00
${maxLoanAmt}=      500000.00
${totalProdLim}=    5000000.00
${totalAssetLim}=   5000000.00
${availAssetLim}=   100000
${availProdLim}=    100000   

*** Keywords ***
Build_Parameter
    [Arguments]    ${product_limit_applicable}    ${asset_limit_applicable}    ${lenderId}     ${lenderName}    
    # 1. Start with the base mandatory fields
    ${lender_detail}     Create Dictionary     id=${lenderId}     lenderName=${lenderName}
    &{PAYLOAD}    Create Dictionary
    ...           lender=${lender_detail}
    ...           productType=${productType}
    ...           assetType=${assetType}
    ...           minimumLoanAmount=${minLoanAmt}
    ...           maximumLoanAmount=${maxLoanAmt}
    # ...           productLimitApplicable=true
    # ...           assetLimitApplicable=true
    ...           totalAssetLimit=${totalAssetLim}    
    ...           availableAssetLimit=${availAssetLim}     
    ...           availableProductLimit=${availProdLim}
    ...           status=True 

    Set Suite Variable     ${productType}
    Set Suite Variable     ${assetType}

    # 2. Convert the input argument to a boolean value for comparison
    ${Product_APPLICABLE}=    Convert To Boolean    ${product_limit_applicable}
    ${Asset_APPLICABLE}=      Convert To Boolean    ${asset_limit_applicable}
    
    # 3. Add conditional fields based on the flag
    Set To Dictionary    ${PAYLOAD}    productLimitApplicable=${Product_APPLICABLE}
    Set To Dictionary    ${PAYLOAD}    assetLimitApplicable=${Asset_APPLICABLE}
    
    # 4. Conditional Check for Product Limit
    IF  ${Product_APPLICABLE} == ${True}    
        Set To Dictionary    ${PAYLOAD}    totalProductLimit=${totalProdLim}
        ELSE
        Remove From Dictionary   ${PAYLOAD}    totalProductLimit    # ELSE: totalProductLimit is omitted
    END

    # 5. Conditional Check for Asset Limit
    IF    ${Asset_APPLICABLE} == ${True}
        Set To Dictionary    ${PAYLOAD}    totalAssetLimit=${totalAssetLim}
        ELSE     
        Remove From Dictionary    ${PAYLOAD}    totalAssetLimit    # ELSE: totalAssetLimit is omitted
    END

    # When the flag is FALSE, the totalProductLimit field is intentionally OMITTED, 
    
    RETURN    ${PAYLOAD} 

TC03_Product Asset_Positive
    [Documentation]    This keyword sets up the environment for LTV-product onboarding tests.
    [Arguments]        ${product_limit_applicable}     ${asset_limit_applicable}    ${lenderId}     ${lenderName}
    Create Session      add_productAsset     ${PRIMARY_CLIENT_URL}     verify=true
    ${REQUEST_BODY}=    Build_Parameter      ${product_limit_applicable}    ${asset_limit_applicable}    ${lenderId}     ${lenderName}          
    ${headers}=         Create Dictionary    Content-Type=application/json
    
    # Log the body to verify the conditional fields were included/excluded
    Log Dictionary    ${REQUEST_BODY}
    
    # B. Execute the POST on Session
    ${RESPONSE}=    POST On Session  add_productAsset    /api/v1/asset-limit-config    json=${REQUEST_BODY}    headers=${headers}    expected_status=${expected_code}    
    
    # D. Optional: Add assertion to ensure correct keys were sent/returned
    Run Keyword If    '${product_limit_applicable}' == 'True'
    ...    Dictionary Should Contain Key    ${REQUEST_BODY}    totalProductLimit
    Run Keyword If    '${product_limit_applicable}' == 'False'
    ...    Dictionary Should Not Contain Key    ${REQUEST_BODY}    totalProductLimit
    
    Run Keyword If    '${asset_limit_applicable}' == 'True'
    ...    Dictionary Should Contain Key    ${REQUEST_BODY}    totalAssetLimit
    Run Keyword If    '${asset_limit_applicable}' == 'False'
    ...    Dictionary Should Not Contain Key    ${REQUEST_BODY}    totalAssetLimit
    
    ${json_data}       Convert String To Json    ${response.content}
    ${id}                   Get Value From Json    ${json_data}    data.id
    ${productAsset_id}      Get From List         ${id}            0
    Log To Console               Product Asset ID: ${productAsset_id}

    RETURN     ${productType}     ${assetType}

# *** Test Cases ***
# TC03_ProductAsset Onboarding_Positive
#     ${lender_id}    ${lenderName}=      TC01_Lender Onboarding_Positive
#     ${productType}     ${assetType}     TC03_Product Asset_Positive     True    True      ${lenderId}     ${lenderName}
    

    
    
