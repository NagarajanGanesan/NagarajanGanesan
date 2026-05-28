*** Settings ***
Resource     ../../../../resources/common.resource
Resource     regression_suite.robot
Resource     01_add_lender.robot
Resource     02_add_distributor.robot
Resource     03_add_product_asset.robot

*** Variables ***
${lender_id}          1
${lender_name}        PARTNER_CLIENT
${Distributor_id}     1
${DistributorName}    Sample Distributor
${intAutoPay}         5
${totalDsaLim}        1000000.0
${availDsaLim}        20000

# Interes_Tenure_Variables
${minLoanAmount}     1000    
${maxLoanAmount}     10000000
${minIntRate}        10.5    
${defaultInttRate}   12    
${maxInttRate}       30.89
${minimumTenure}     12    
${defaultTenure}     15    
${maximumTenure}     30

# Product_interest Share
${lenderShare}       34.5    
${exampleDistributorInterestShareType}     1
${exampleShare}      55    
${distributorShare}  45

# Fees Config Variables
${feeName}          asdfASS
${feeType}          1
${feeCalculation}   1
${feeValue}         500
${minFeeAmount}     100
${maxFeeAmount}     1231
${feeBasis}         sdsd
${feeCondition}     sdfcvs
${lenderPreFixed}   12
${gstType}          1
# Already in Porduct int share
# ${lenderShare}     12
# ${exampleDistributorFeeShare}     BALANCE
# ${exampleShare}     23
# ${distributorShare}     12

*** Keywords ***
Build Product Configuration Payload
    [Documentation]    Builds the complete product JSON, conditionally including DSA limits.
    [Arguments]    ${dsa_limit_applicable_flag}    ${lender_id}    ${lender_name}    ${Distributor_id}     ${DistributorName}     ${DEDUCT_AT_DISBURSEMENT_STATUS}     ${GST_APPLICABLE_STATUS}
    
    # ${productName}     FakerLibrary.Cryptocurrency Name
    Create Session     product_session      ${PRIMARY_CLIENT_URL}     verify=true
    ${productName}     FakerLibrary.Cryptocurrency Name
    # 1. Initialize the Base Payload Dictionary
    &{PAYLOAD}    Create Dictionary
    ...           productName=${productName}
    ...           productType=${productType}
    ...           assetType=${assetType}
    &{LENDER_OBJ}       Create Dictionary   id=${lender_id}    lenderName=${lender_name}
    # &{DISTRIBUTOR_OBJ}  Create Dictionary    id=${Distributor_id}       distributorName=${DistributorName}
    # Set To Dictionary    ${PAYLOAD}    distributor=${DISTRIBUTOR_OBJ}
    Set To Dictionary    ${PAYLOAD}    lender=${LENDER_OBJ}
    ...           interestAutopayDay=${intAutoPay}
    ...           status=True
    
    # Add Nested Dictionaries (Lender and Distributor)
    ${dsa_flag}=    Convert To Boolean    ${dsa_limit_applicable_flag}
    Set To Dictionary    ${PAYLOAD}    dsaLimitApplicable=${dsa_limit_applicable_flag}

    # Handle Conditional DSA Limit
    IF  ${dsa_flag} == ${True}
        # If TRUE: Include the limit values
        Set To Dictionary    ${PAYLOAD}    totalDsaLimit=${totalDsaLim}
        Set To Dictionary    ${PAYLOAD}    availableDsaLimit=${availDsaLim}
        ELSE
        # If FALSE: Remove the keys to omit them from the JSON request
        Remove From Dictionary    ${PAYLOAD}    totalDsaLimit
        Remove From Dictionary    ${PAYLOAD}    availableDsaLimit
    END
   
    # 2. Add Nested Lists (Interest/Tenure Config and Fees)
    # Define productInterestTenureConfig LIST
    &{INT_TENURE_CONFIG_ITEM}    Create Dictionary  
    ...    minimumLoanAmount=${minLoanAmount}    
    ...    maximumLoanAmount=${maxLoanAmount}
    ...    minimumInterestRate=${minIntRate}   
    ...    defaultInterestRate=${defaultInttRate}    
    ...    maximumInterestRate=${maxInttRate}
    ...    minimumTenure=${minimumTenure}    
    ...    defaultTenure=${defaultTenure}   
    ...    maximumTenure=${maximumTenure}

    ${INTEREST_TENURE_CONFIG_LIST}=    Create List    ${INT_TENURE_CONFIG_ITEM}
    Set To Dictionary    ${PAYLOAD}    productInterestTenureConfig=${INTEREST_TENURE_CONFIG_LIST}

    # 3. Define productInterestShare DICTIONARY
    &{INTEREST_SHARE}     Create Dictionary   
    ...    lenderShare=${lenderShare}    
    ...    exampleDistributorInterestShareType=${exampleDistributorInterestShareType}
    ...    exampleShare=${exampleShare}   
    ...    distributorShare=${distributorShare}

    Set To Dictionary    ${PAYLOAD}    productInterestShare=${INTEREST_SHARE}
    
    # Builds the single dictionary for the 'fees' array, handling the conditional logic
    &{FEE_DETAILS}=    Create Dictionary
    ...    feeName=${feeName}
    ...    feeType=${feeType}
    ...    feeCalculationTypeEnum=${feeCalculation}
    ...    feeValue=${feeValue}
    ...    minFeeAmount=${minFeeAmount}
    ...    maxFeeAmount=${maxFeeAmount}
    ...    feeBasis=${feeBasis}
    ...    feeCondition=${feeCondition}
    ...    deductAtDisbursement=${DEDUCT_AT_DISBURSEMENT_STATUS}  # Controlled by argument
    ...    gstApplicable=${GST_APPLICABLE_STATUS}                 # Controlled by argument
    ...    lenderPreFixedValue=${lenderPreFixed}
    ...    lenderShare=${lenderShare}
    ...    exampleDistributorFeeShareType=${exampleDistributorInterestShareType}
    ...    exampleShare=${exampleShare}
    ...    distributorShare=${distributorShare}
    ...    status=${TRUE}

    # --- Conditional Removal Logic ---
    # 1. If deductAtDisbursement is False, remove the 'deductAtDisbursement' key entirely.
    Run Keyword If    '${DEDUCT_AT_DISBURSEMENT_STATUS}' == '${FALSE}'
    ...    Remove From Dictionary    ${FEE_DETAILS}    deductAtDisbursement

    # 2. If gstApplicable is False, remove 'gstType' and 'gstValue' (If they were present. They are commented out in the source, but included here for completeness/future use.)
    # Note: Since they were commented out in your JSON, we only rely on the ${GST_APPLICABLE_STATUS} for the 'gstApplicable' field itself.
    IF  '${GST_APPLICABLE_STATUS}' == '${True}'  
        Set To Dictionary    ${FEE_DETAILS}      gstType=1
        Set To Dictionary    ${FEE_DETAILS}      gstValue=18
        ELSE
        Remove From Dictionary    ${FEE_DETAILS}     gstType
        Remove From Dictionary    ${FEE_DETAILS}     gstValue
    END
    
    # Create the 'fees' list containing the single fee dictionary
    ${FEES_LIST}=    Create List    ${FEE_DETAILS}
    Set To Dictionary    ${PAYLOAD}    fees=${FEES_LIST}
    RETURN    ${PAYLOAD}

# =========================================================================
# KEYWORD TO EXECUTE THE REQUEST AND VALIDATION
# =========================================================================
TC05_Product_Positive
    [Arguments]     ${cookies}     ${client_Id}     ${api_key}     ${app_code}    ${dsa_limit_applicable_flag}    ${lender_id}    ${lender_name}    ${Distributor_id}     ${DistributorName}     ${deductAt_Disbursement}     ${gst_Applicable}
    
    # A. Build the Conditional Payload
    ${REQUEST_BODY}=   Build Product Configuration Payload    ${dsa_limit_applicable_flag}    ${lender_id}    ${lender_name}    ${Distributor_id}     ${DistributorName}     ${deductAt_Disbursement}     ${gst_Applicable}
    
    ${headers}         Create Dictionary    Content-Type=application/json
    ...    Cookie=${cookies}
    ...    X-CLIENT-ID=${client_Id}     
    ...    X-API-KEY=${api_key}     
    ...    app-code=${app_code}
    Log Dictionary     ${REQUEST_BODY}
    
    # B. Execute the POST on Session
    ${RESPONSE}=       POST On Session    product_session       url=/api/v1/product    json=${REQUEST_BODY}     headers=${headers}    expected_status=${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${id}              Get Value From Json    ${json_data}    data.id
    ${Product_id}      Get From List          ${id}            0
    Log To Console     Product Id: ${Product_id}

    ${id}              Get Value From Json    ${json_data}    data.productCode
    ${Product_Code}    Get From List         ${id}            0
    Log To Console     Product Code: ${Product_Code}

    Set Suite Variable    ${Product_id}
    Set Suite Variable    ${Product_Code}

    RETURN     ${Product_id}     ${Product_Code}        #${dsa_limit_applicable_flag}     ${deductAt_Disbursement}     ${gst_Applicable}   

# *** Test Cases ***
# TC05_Product Onboarding_Positive
#     [Documentation]       This suite includes test cases that verify successful product creation,
#     ${lender_id}    ${lenderName}=    TC01_Lender Onboarding_Positive
#     ${Distributor_id}    ${DistributorName}=    TC02_Distributor Onboarding_Positive
#     ${Product_id}     ${Product_Code}      TC05_Product_Positive    True    ${lender_id}    ${lender_name}    ${Distributor_id}     ${DistributorName}     True     True