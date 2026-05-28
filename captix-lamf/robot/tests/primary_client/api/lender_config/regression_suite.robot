*** Settings ***
Resource     ../../../../resources/common.resource
Resource     01_add_lender.robot
Resource     02_add_distributor.robot
Resource     03_add_product_asset.robot
Resource     04_add_ltv_subtype.robot
Resource     05_add_product.robot

*** Variables ***
${lenderId}          1
${lenderName}        PARTNER_CLIENT
${Distributor_id}    1
${DistributorName}   Sample Distributor

${app_code}     55555555-6666-7777-8888-999999999999
${userName}     admin
${password}     ChangeMe_AdminPass_123
${userId}       1
${userRole}     1
${login_type}   NORMAL

*** Test Cases ***
Regression_Suite
    [Documentation]     LenderOnboarding, Distributor Onboarding, Product Asset Limit
    ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${branchCode}      01_Login as user
    ${lender_id}  ${lenderName}=     TC01_Lender Onboarding_Positive    ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    # ${Distributor_id}   ${DistributorName}=    TC02_Distributor Onboarding_Positive
    # ${productType}     ${assetType}    TC03_Product Asset_Positive     True    True      ${lenderId}     ${lenderName}
    # TC04_LtvAssetSubType_Positive     True      ${lenderId}     ${lenderName}
    TC05_Product_Positive      ${cookies}     ${client_Id}     ${api_key}     ${app_code}     True    ${lender_id}    ${lender_name}    ${Distributor_id}     ${DistributorName}     True     True
    Logout                     ${cookies}     ${client_Id}     ${api_key}     ${app_code} 

*** Keywords ***
01_Login as user    
    [Documentation]    Auth login test to verify the created user
    Create Session     user_login     url= ${PRIMARY_CLIENT_URL}     verify=true
    
    ${db}=    Get From Dictionary       ${DB_CONFIGS}    ${ENV}
    Connect To Database    psycopg2     ${db.name}     ${db.Username}     ${db.Password}     ${db.Host}     ${db.Port}    None    
    ${access_token}     Query     SELECT api_key, client_id FROM ${primary_client_schemeName}.partner_product_config WHERE app_code = '${app_code}'; 

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
    ...        login_type=${login_type}
    ${response}        POST On Session      user_login     /api/v1/auth/login     json=${body}     headers=${headers}
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
    ${access_token}=     Get From Dictionary    ${cookies}    apicore-access-token
    ${refresh_token}=    Get From Dictionary    ${cookies}    apicore-refresh-token

    Log    ${access_token}
    Log    ${refresh_token}

    ${cookies}    Set Variable    apicore-access-token=${access_token}; apicore-refresh-token=${refresh_token}; user_id=${userId}; user_roles=${userRole}  

    Log To Console     ${user_name}: 01_${msg}

    RETURN     ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${branchCode}

Logout
    [Arguments]     ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]       User_logout
    Create Session        logout     url= ${PRIMARY_CLIENT_URL}     verify=true
    ${headers}            Create Dictionary    Content-Type=application/json
        ...    Cookie=${cookies}
        ...    X-CLIENT-ID=${client_Id}     
        ...    X-API-KEY=${api_key}     
        ...    app-code=${app_code}
    ${response}     GET On Session     logout     /api/v1/auth/logout     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}     Get From List    ${status_msg}    0 
    Log To Console    user: ${msg}   

