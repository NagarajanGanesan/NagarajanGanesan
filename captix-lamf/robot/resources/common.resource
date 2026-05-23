*** Settings ***
Resource    imports.resource
Resource    variables.resource

*** Keywords ***
Open Browsers
    [Arguments]    ${url}    ${browser}
    Open Browser    ${url}   browser=${browser}
    Maximize Browser Window

Generate_Random PAN
    ${letters}=    Set Variable    ABCDEFGHIJKLMNOPQRSTUVWXYZ
    ${first5}=     Evaluate    ''.join(random.choices('${letters}', k=5))    random
    ${digits}=     Evaluate    ''.join(random.choices('0123456789', k=4))    random
    ${last}=       Evaluate    random.choice('${letters}')    random
    ${panNo}=      Set Variable    ${first5}${digits}${last}
    RETURN         ${panNo}

Generate Random GSTIN
    ${state_code}=    Evaluate    random.randint(1, 35)    random
    ${state_code}=    Evaluate    f"{${state_code}:02d}"

    ${pan}=           Generate Random PAN

    ${entity_code}=   Evaluate    random.choice('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')    random
    ${z_letter}=      Set Variable    Z
    ${checksum}=      Evaluate    random.choice('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')    random

    ${gstin}=         Set Variable    ${state_code}${pan}${entity_code}${z_letter}${checksum}
    RETURN          ${gstin}

Generate Random Mobile Number
    ${start_digit}=    Evaluate    random.choice('6789')    random
    ${remaining}=      Evaluate    ''.join(random.choices('0123456789', k=9))    random
    ${mobile}=         Set Variable    ${start_digit}${remaining}
    RETURN           ${mobile}

Generate Random Aadhaar
    [Documentation]    Generates a random 12-digit Aadhaar number.
    ${random_aadhar}=    FakerLibrary.Random Number    digits=12    fix_len=True
    RETURN    ${random_aadhar}

Generate Random Address
    [Documentation]    Generates an address and removes all special characters.
    ${raw_address}=    FakerLibrary.Address
    ${no_newlines}=    Replace String    ${raw_address}    \n    ${SPACE}
    ${clean_address}=    Replace String Using Regexp    ${no_newlines}    [^a-zA-Z0-9 ]    ${EMPTY}
    ${random_address}=    Replace String Using Regexp    ${clean_address}    \\s+    ${SPACE}
    RETURN    ${random_address}

Refresh
    [Arguments]        ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]    Refresh api
    Create Session     refresh_api     url=${PRIMARY_CLIENT_URL}     verify=true
    ${headers}         Create Dictionary    Content-Type=application/json
    ${response}        GET On Session       refresh_api     /api/v1/gateway/refresh-mapping    headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}

Refresh_route
    [Arguments]     ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]    Refresh route
    Create Session     refresh_route        url=${PRIMARY_CLIENT_URL}     verify=true
    ${headers}         Create Dictionary    Content-Type=application/json
    ${response}        GET On Session       refresh_route     /api/v1/gateway/refresh-mapping/routes    headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}

Compute Expiry Date
    [Documentation]    Returns a date randomly 2-6 months from today (YYYY-MM-DD).
    ${exp_date}=    Evaluate
    ...    (__import__('datetime').datetime.now() + __import__('datetime').timedelta(days=__import__('random').randint(60, 180))).strftime('%Y-%m-%d')
    Log To Console    Expiry date = ${exp_date}
    RETURN    ${exp_date}
