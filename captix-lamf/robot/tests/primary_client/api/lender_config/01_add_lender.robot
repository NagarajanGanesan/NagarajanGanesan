*** Settings ***
Resource    ../../../../resources/common.resource

*** Keywords ***
TC01_Lender Onboarding_Positive
    [Arguments]     ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]   This keyword sets up the environment for lender onboarding tests.
    Create Session    lender_onboarding    url=${PRIMARY_CLIENT_URL}     verify=true

    ${lenderName}=    Generate Random String    3    [UPPER]
    ${email_Id}=      FakerLibrary.Safe Email
    ${contact}=       Generate Random Mobile Number
    ${reg_Address}=   FakerLibrary.Address
    ${PAN}=           Generate Random PAN
    ${gstIn}=         Generate Random GSTIN
    ${logo}=          Create List    12    23    12

    Set Suite Variable   ${lenderName}
    Set Test Variable    ${email_Id}
    Set Test Variable    ${contact}
    Set Test Variable    ${reg_Address}
    Set Test Variable    ${PAN}
    Set Test Variable    ${gstIn}
    Set Test Variable    ${logo}

    ${data}=    Create Dictionary
    ...    lenderName=${lenderName}
    ...    email=${email_Id}
    ...    contactNo=${contact}
    ...    registeredAddress=${reg_Address}
    ...    pan=${PAN}
    ...    status=true
    ...    gstIn=${gstIn}
    ...    logo=${logo}

    ${headers}         Create Dictionary    Content-Type=application/json
    ...    Cookie=${cookies}
    ...    X-CLIENT-ID=${client_Id}     
    ...    X-API-KEY=${api_key}     
    ...    app-code=${app_code}

    ${response}=       Post On Session      lender_onboarding    /api/v1/lender    json=${data}    headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${id}              Get Value From Json    ${json_data}    data.id
    ${lender_id}       Get From List    ${id}    0

    ${Post_pan}=       Get Value From Json    ${json_data}    data.pan
    ${PAN_No}          Get From List          ${Post_pan}     0

    ${Post_gst}=       Get Value From Json    ${json_data}    data.gstIn
    ${GST_No}          Get From List          ${Post_gst}     0

    Log to console     Lender ID is: ${lender_id}
    Set Suite Variable    ${lender_id}
    
    RETURN    ${lender_id}   ${lenderName}

# *** Test Cases ***
# TC01_Lender Onboarding_Positive
#     ${lender_id}  ${lenderNmae}=    TC01_Lender Onboarding_Positive
