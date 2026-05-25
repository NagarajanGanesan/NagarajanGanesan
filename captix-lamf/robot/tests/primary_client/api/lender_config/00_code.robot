*** Settings ***
Resource    ../../../../resources/common.resource

*** Variables ***
@{TYPE_NAMES}    accountType    assetSubType    holdingModes

*** Keywords ***
create_code
    Create Session    code_api     ${PRIMARY_CLIENT_URL}    verify=true    
    ${headers}=       Create Dictionary    Content-Type=application/json
    
    FOR    ${name_value}    IN    @{TYPE_NAMES}
        # 1. Construct the JSON body dynamically
        ${body}=    Create Dictionary    name=${name_value}    status=${True}
        
        # 2. Hit the API
        ${response}=    POST On Session    code_api    /api/v1/code    
        ...    json=${body}    
        ...    headers=${headers}    
        ...    expected_status=${expected_code}
        
        # 3. Log results for debugging
        Log To Console    Testing name: ${name_value} - Status: ${response.status_code}
    END

# *** Test Cases ***
# TC01_Post_API_Code
#     create_code
    