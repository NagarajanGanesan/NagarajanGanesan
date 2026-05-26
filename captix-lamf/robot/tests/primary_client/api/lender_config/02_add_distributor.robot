*** Settings ***
Resource    ../../../../resources/common.resource

*** Keywords ***
TC02_Distributor Onboarding_Positive
    [Documentation]   This keyword sets up the environment for Distributor onboarding tests.
    Create Session     Distributor_onboarding    $${PRIMARY_CLIENT_URL}     verify=true
    ${DistributorName}=   FakerLibrary.Distributor
    ${email_Id}=          FakerLibrary.Safe Email
    ${contact}=           Generate Random Mobile Number
    ${reg_Address}=       FakerLibrary.Address
    ${PAN}=               Generate Random PAN
    ${gstIn}=             Generate Random GSTIN
    ${logo}=              Create List    12    23    12
    ${bankAccountName}=   Generate Bank Name     
    # FakerLibrary.Bank
    ${bankAccountNo}=     Generate Account Number   ${bankAccountName}      #Generate Random Bank Account Number
    ${ifsc_code}=         Generate Ifsc   ${bankAccountName}
    ${accountType}=       Create Dictionary    codesId=2    name=DEBT

    Set Suite Variable   ${DistributorName}
    Set Test Variable    ${email_Id}
    Set Test Variable    ${contact}
    Set Test Variable    ${reg_Address}
    Set Test Variable    ${PAN}
    Set Test Variable    ${gstIn}
    Set Test Variable    ${logo}
    Set Test Variable    ${bankAccountName}
    Set Test Variable    ${bankAccountNo} 
    Set Test Variable    ${ifsc_code}

    ${data}=    Create Dictionary
    ...    distributorName=${DistributorName}
    ...    email=${email_Id}
    ...    contactNo=${contact}
    ...    registeredAddress=${reg_Address}
    ...    pan=${PAN}
    ...    status=true
    ...    gstIn=${gstIn}
    ...    logo=${logo}
    ...    bankAccountName=${bankAccountName}
    ...    bankAccountNo=${bankAccountNo}
    ...    ifscCode=${ifsc_code}
    ...    accountType=${accountType}
    

    ${headers}=        Create Dictionary    Content-Type=application/json
    ${response}=       Post On Session      Distributor_onboarding    /api/v1/distributors    json=${data}    headers=${headers}     expected_status=${expected_code}
    ${status_code}=    Convert To String    ${response.status_code}

    ${json_data}       Convert String To Json    ${response.content}
    ${id}              Get Value From Json    ${json_data}    data.id
    ${Distributor_id}       Get From List     ${id}    0

    ${Post_pan}=       Get Value From Json    ${json_data}    data.pan
    ${PAN_No}          Get From List          ${Post_pan}     0

    ${Post_gst}=       Get Value From Json    ${json_data}    data.gstIn
    ${GST_No}          Get From List          ${Post_gst}     0

    Log to console     Distributor ID: ${Distributor_id}
    Set Suite Variable    ${Distributor_id}
    
    RETURN    ${Distributor_id}    ${DistributorName}  

# *** Test Cases ***
# TC01_Lender Onboarding_Positive
#     ${Distributor_id}    ${DistributorName}=    TC02_Distributor Onboarding_Positive
