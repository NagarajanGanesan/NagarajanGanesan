*** Settings ***
Documentation     Common Login / Logout for PRIMARY_CLIENT mock regression (OD + TL).
Resource          ../common.resource
Resource          ../build_header.resource

*** Keywords ***
# ─── Login ────────────────────────────────────────────────────────────────────
TC_01 Login
    [Documentation]    DB-driven credentials → POST /api/v1/auth/login.
    ...                Returns cookies + client info; called from Suite Setup Auth.
    Create Session     user_login     url=${QA_URL}     verify=true

    ${db}=    Get From Dictionary       ${DB_CONFIGS}    ${ENV}
    Connect To Database    psycopg2     ${db}[name]      ${db}[Username]     ${db}[Password]     ${db}[Host]     ${db}[Port]    None
    ${access_token}     Query     SELECT api_key, client_id FROM ${qa_schemeName}.partner_product_config WHERE app_code = '${app_code}';

    ${key&Id}      Get From List     ${access_token}    0
    ${api_key}     Get From List     ${key&Id}          0
    ${client_Id}   Get From List     ${key&Id}          1
    Log  clientId: ${client_Id}
    Disconnect From Database

    ${headers}         Create Dictionary    Content-Type=application/json
    ...    X-CLIENT-ID=${client_Id}
    ...    X-API-KEY=${api_key}
    ...    app-code=${app_code}
    ${body}    Create Dictionary
    ...        username=${userName}
    ...        userpassword=${password}
    ...        login_type=AD
    ${response}        POST On Session      user_login     /api/v1/auth/adlogin     json=${body}     headers=${headers}     expected_status=any
    ${status_code}=    Convert To String    ${response.status_code}
    IF    '${status_code}' == '400' and 'User already logged in' in '''${response.text}'''
        Fail    msg=Login blocked: a previous session for user '${userName}' is still active on the gateway. Wait for the session to expire (typically 15-60 min) or have the user log out from another client. Raw: ${response.text}
    END
    Should Be Equal    ${status_code}       ${expected_code}    msg=Login failed: ${response.text}

    ${json_data}       Convert String To Json    ${response.content}
    ${message}         Get Value From Json       ${json_data}     status.code
    ${msg}             Get From List             ${message}       0
    ${branch}          Get Value From Json       ${json_data}     data.branch_code
    ${branchCode}      Get From List             ${branch}        0
    ${name}            Get Value From Json       ${json_data}     data.user_name
    ${user_name}       Get From List             ${name}          0

    ${cookies}=          Set Variable    ${response.cookies.get_dict()}
    ${access_token}=     Get From Dictionary    ${cookies}     ${app_code}_x-access-token
    ${refresh_token}=    Get From Dictionary    ${cookies}     ${app_code}_x-refresh-token
    ${userId}=           Get From Dictionary    ${cookies}     ${app_code}_user_id
    ${userRole}          Get From Dictionary    ${cookies}     ${app_code}_user_roles

    ${cookies}    Set Variable    ${app_code}_x-access-token=${access_token}; ${app_code}_x-refresh-token=${refresh_token}; ${app_code}_user_id=${userId}; ${app_code}_user_roles=${userRole}

    Log To Console     TC_01: ${user_name} ${msg}

    RETURN     ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${branchCode}

# ─── Logout ───────────────────────────────────────────────────────────────────
Logout
    [Documentation]    Only called in LOGIN mode — no logout for HMAC.
    Create Session     logout     url=${QA_URL}     verify=true
    ${headers}=        Build Get Headers
    ${response}        GET On Session     logout     /api/v1/auth/logout     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}             Get From List          ${status_msg}     0
    Log To Console     Logout: ${msg}

# ─── Auth Setup ───────────────────────────────────────────────────────────────
Suite Setup Auth
    [Documentation]    If app_code is set: login and store cookies as suite vars.
    ...                If app_code is ${NONE}: prepare HMAC mode (no login).
    IF    $app_code is not None and str($app_code).upper() != 'NONE'
        ${cookies}    ${client_Id}    ${api_key}    ${ac}    ${branchCode}=    TC_01 Login
        Set Suite Variable    ${suite_cookies}      ${cookies}
        Set Suite Variable    ${suite_client_Id}    ${client_Id}
        Set Suite Variable    ${suite_api_key}      ${api_key}
        Set Suite Variable    ${suite_app_code}     ${ac}
        Log To Console    Auth Mode: LOGIN — app_code=${ac}
    ELSE
        Set Suite Variable    ${suite_client_Id}    ${primary_client-client-id}
        Set Suite Variable    ${suite_api_key}      ${primary_client-api-key}
        Log To Console    Auth Mode: HMAC — no login, using gateway HMAC signature
    END

Suite Teardown Auth
    [Documentation]    Logout only in LOGIN mode. ${suite_app_code} defaults to None in BuildHeader.
    IF    $suite_app_code is not None
        Logout
    END
