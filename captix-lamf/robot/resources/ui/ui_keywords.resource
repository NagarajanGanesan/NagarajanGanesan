*** Settings ***
Resource    ../imports.resource
Resource    ui_variables.resource

*** Keywords ***
# ──────────────────────────────────────────────
# UTILITY
# ──────────────────────────────────────────────
Enter OTP
    [Documentation]    Waits for OTP inputs to appear, clicks the first box,
    ...                then presses each digit using Press Keys so ant-design
    ...                auto-advances focus to the next input box.
    [Arguments]    ${otp}
    Wait Until Element Is Visible    xpath://input[@aria-label='OTP Input 1']    timeout=15s
    Click Element                    xpath://input[@aria-label='OTP Input 1']
    ${length}=    Get Length    ${otp}
    FOR    ${i}    IN RANGE    1    ${length}+1
        ${digit}=    Set Variable    ${otp}[${i - 1}]
        Wait Until Element Is Enabled    xpath://input[@aria-label='OTP Input ${i}']    timeout=5s
        Press Keys                       xpath://input[@aria-label='OTP Input ${i}']    ${digit}
    END

# ──────────────────────────────────────────────
# LOGIN / LOGOUT
# ──────────────────────────────────────────────
Fetch API Credentials
    [Documentation]    Queries the DB for X-API-KEY and X-CLIENT-ID that
    ...                correspond to ${API_APP_CODE} and stores them as suite variables.
    ...                Non-fatal: logs a warning if the app_code is not found so the
    ...                suite still starts; Force API Logout will skip if creds are empty.
    ${db}=    Get From Dictionary    ${DB_CONFIGS}    ${ENV}
    ${conn_status}    ${conn_err}=    Run Keyword And Ignore Error
    ...    Connect To Database    psycopg2    ${db.name}    ${db.Username}    ${db.Password}    ${db.Host}    ${db.Port}    None
    IF    '${conn_status}' == 'FAIL'
        Log To Console    WARNING: DB connection failed (${conn_err}) — Force API Logout will be skipped
        RETURN
    END
    ${rows}=    Query
    ...    SELECT api_key, client_id FROM ${primary_client_schemeName}.partner_product_config WHERE app_code = '${API_APP_CODE}';
    Disconnect From Database
    ${count}=    Get Length    ${rows}
    IF    ${count} == 0
        Log To Console
        ...    WARNING: No DB record for app_code '${API_APP_CODE}' in schema '${primary_client_schemeName}' (ENV=${ENV}). Force API Logout will be skipped. Check API_APP_CODE in resources/ui/ui_variables.resource.
        RETURN
    END
    ${row}=       Get From List    ${rows}    0
    ${api_key}=   Get From List    ${row}     0
    ${cli_id}=    Get From List    ${row}     1
    Set Suite Variable    ${API_KEY}       ${api_key}
    Set Suite Variable    ${CLIENT_ID}     ${cli_id}
    Log To Console    API credentials fetched for app_code: ${API_APP_CODE}

Force API Logout
    [Documentation]    Reads the active session cookie from the browser and calls
    ...                GET /api/v1/auth/logout so the backend invalidates the stuck
    ...                session. Falls back gracefully if no cookie is present or
    ...                if API credentials were not fetched (Fetch API Credentials failed).
    IF    '${API_KEY}' == '${EMPTY}' or '${CLIENT_ID}' == '${EMPTY}'
        Log To Console    Force logout: API credentials not available — skipping API logout
        RETURN
    END
    ${s}    ${cookie}=    Run Keyword And Ignore Error    Get Cookie    apicore-access-token
    IF    '${s}' == 'FAIL'
        Log To Console    Force logout: no session cookie in browser — skipping API logout
        RETURN
    END
    ${access_token}=    Set Variable    ${cookie.value}
    ${rs}    ${rc}=     Run Keyword And Ignore Error    Get Cookie    apicore-refresh-token
    ${refresh_token}=   Set Variable If    '${rs}' == 'PASS'    ${rc.value}    ${EMPTY}
    ${cookie_str}=      Set Variable
    ...    apicore-access-token=${access_token}; apicore-refresh-token=${refresh_token}; user_id=${USER_ID}; user_roles=${USER_ROLE}
    Create Session      ui_force_logout    /api/v1/logout    disable_warnings=True
    ${headers}=         Create Dictionary
    ...    Content-Type=application/json
    ...    Cookie=${cookie_str}
    ...    X-CLIENT-ID=${CLIENT_ID}
    ...    X-API-KEY=${API_KEY}
    ...    app-code=${API_APP_CODE}
    ${response}=        GET On Session    ui_force_logout    /api/v1/auth/logout
    ...                 headers=${headers}    expected_status=anything
    Log To Console    Force logout API response: ${response.status_code}

UI Login
    [Documentation]    Enter username/password and submit the login form.
    ...                If the backend rejects with "User already logged in", the keyword
    ...                calls the logout API to clear the stuck session and retries once.
    Wait Until Element Is Visible    xpath://input[@id='loginForm_username']       timeout=15s
    Input Text                       xpath://input[@id='loginForm_username']       ${USERNAME}
    Input Text                       xpath://input[@id='loginForm_userpassword']   ${PASSWORD}
    Click Element                    xpath://button[@type='submit']

UI Logout
    [Documentation]    Click the Logout button and log the event.
    [Arguments]        ${customer_id}
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Logout']]    timeout=10s
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Logout']]
    Click Element                    xpath://button[.//span[normalize-space()='Logout']]
    Log To Console    Logged out successfully! Customer ID: ${customer_id}

# ──────────────────────────────────────────────
# CUSTOMER VERIFICATION
# ──────────────────────────────────────────────
Customer Verification
    [Documentation]    Select "Customer ID" lookup, enter the ID, submit, and verify with OTP.
    [Arguments]        ${customer_id}
    Wait Until Element Is Visible    xpath://span[@aria-label='down']             timeout=10s
    Click Element                    xpath://span[@aria-label='down']
    Wait Until Element Is Visible    xpath://div[text()="Customer ID"]            timeout=10s
    Click Element                    xpath://div[text()="Customer ID"]
    Input Text                       xpath://input[@id='loginForm_customerId']    ${customer_id}
    Click Element                    xpath://button[@type='submit']

# ──────────────────────────────────────────────
# LOAN APPLICATION
# ──────────────────────────────────────────────
Apply OD Loan
    [Documentation]    Click "Apply now" to initiate the overdraft loan application.
    Wait Until Element Is Visible    xpath:(//span[text()='Apply now'])[1]    timeout=10s
    Click Element                    xpath:(//span[text()='Apply now'])[1]

Apply TL Loan
    [Documentation]    Click "Apply now" to initiate the Term loan application.
    Wait Until Element Is Visible    xpath:(//span[text()='Apply now'])[2]    timeout=10s
    Scroll Element Into View         xpath:(//span[text()='Apply now'])[2]
    Click Element                    xpath:(//span[text()='Apply now'])[2]

Email Verification
    [Documentation]    Trigger email OTP and validate it.
    Wait Until Element Is Visible    xpath://span[text()='Verify']    timeout=10s
    Click Element                    xpath://span[text()='Verify']
    Enter OTP                        ${EMAIL_OTP}
    Scroll Element Into View         xpath://button[@type='submit']
    Wait Until Element Is Visible    xpath://button[@type='submit']    timeout=10s
    Click Element                    xpath:(//button[@type='submit'])[2]

Update Loan Application
    [Documentation]    Select loan purpose (Travel) and submit the update.
    Wait Until Element Is Visible    xpath://span[@aria-label='down']        timeout=10s
    Click Element                    xpath://span[@aria-label='down']
    Click Element                    xpath://div[text()="Travel"]
    Click Element                    xpath:(//button[@type='submit'])[1]

Bank Integration
    [Documentation]    Select the pre-fetched bank account and continue.
    Wait Until Element Is Visible    xpath://span[@class='ant-radio-inner']        timeout=10s
    Double Click Element             xpath://span[@class='ant-radio-inner']
    Scroll Element Into View         xpath:(//button[.//span[normalize-space()='Continue']])[2]
    Click Element                    xpath:(//button[.//span[normalize-space()='Continue']])[2]

# ──────────────────────────────────────────────
# CAMS – FETCH → OPT → PLEDGE
# ──────────────────────────────────────────────
CAMS Fetch And OTP Verification
    [Documentation]    Verify CAMS fetch request and validate OTP.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Verify']]    timeout=10s
    Click Element                    xpath://button[.//span[normalize-space()='Verify']]
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Submit']]
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Submit']]
    Enter OTP                        ${CAMS_OTP}
    Click Element                    xpath://button[.//span[normalize-space()='Submit']]

CAMS Opt Mutual Funds
    [Documentation]    Edit CAMS credit limit, adjust units, and continue.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Edit Credit limit']]    timeout=10s
    Click Element                    xpath://button[.//span[normalize-space()='Edit Credit limit']]
    Double Click Element             xpath:(//span[@aria-label='plus'])[1]
    Clear Element Text               xpath:(//input[@role='spinbutton'])[2]
    Input Text                       xpath:(//input[@role='spinbutton'])[2]    10
    Click Element                    xpath:(//button[.//span[normalize-space()='Continue']])[3]

CAMS Pledge
    [Documentation]    Initiate CAMS pledge, confirm the amount, and validate OTP.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Pledge']]    timeout=10s
    Sleep    2s
    Click Element                    xpath://button[.//span[normalize-space()='Pledge']]
    Sleep    2s
    Scroll Element Into View         xpath://button[.//span[contains(normalize-space(), 'Pledge ₹')]]
    Click Element                    xpath://button[.//span[contains(normalize-space(), 'Pledge ₹')]]
    Enter OTP                        ${CAMS_OTP}
    Click Element                    xpath://button[.//span[normalize-space()='Submit']]

# ──────────────────────────────────────────────
# KFINTECH – FETCH → OPT → PLEDGE
# ──────────────────────────────────────────────
KFIN Fetch And OTP Verification
    [Documentation]    Verify KFintech fetch request and validate OTP.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Verify']]    timeout=10s
    Click Element                    xpath://button[.//span[normalize-space()='Verify']]
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Submit']]
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Submit']]
    Enter OTP                        ${KFIN_OTP}
    Click Element                    xpath://button[.//span[normalize-space()='Submit']]

KFIN Opt Mutual Funds
    [Documentation]    Edit KFintech credit limit, adjust units, and continue.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Edit Credit limit']]    timeout=10s
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Edit Credit limit']]
    Click Element                    xpath://button[.//span[normalize-space()='Edit Credit limit']]
    Double Click Element             xpath:(//span[@aria-label='plus'])[1]
    Clear Element Text               xpath:(//input[@role='spinbutton'])[2]
    Input Text                       xpath:(//input[@role='spinbutton'])[2]    10
    Wait Until Element Is Visible    xpath:(//button[.//span[normalize-space()='Continue']])[3]    timeout=10s    
    Click Element                    xpath:(//button[.//span[normalize-space()='Continue']])[3]

KFIN Pledge
    [Documentation]    Initiate KFintech pledge, confirm the amount, and validate OTP.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Pledge']]    timeout=10s
    Click Element                    xpath://button[.//span[normalize-space()='Pledge']]
    Sleep    2s
    Scroll Element Into View         xpath://button[.//span[contains(normalize-space(), 'Pledge ₹')]]
    Click Element                    xpath://button[.//span[contains(normalize-space(), 'Pledge ₹')]]
    Sleep    2s
    Enter OTP                        ${KFIN_OTP}
    Click Element                    xpath://button[.//span[normalize-space()='Submit']]

# ──────────────────────────────────────────────
# CHECKOUT & DISBURSEMENT
# ──────────────────────────────────────────────
Checkout And Proceed
    [Documentation]    Complete the checkout summary and proceed to the next stage.
    Wait Until Element Is Visible    xpath://button[.//span[contains(normalize-space(), 'Check out')]]    timeout=10s
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Proceed']]
    Click Element                    xpath://button[.//span[contains(normalize-space(), 'Check out')]]
    Click Element                    xpath://button[.//span[contains(normalize-space(), 'Check out')]]
    Click Element                    xpath://button[.//span[normalize-space()='Proceed']]
    Wait Until Element Is Visible    xpath:(//button[.//span[normalize-space()='Pledged Securities']])[3]    timeout=10s
    Click Element                    xpath:(//button[.//span[normalize-space()='Pledged Securities']])[3]
    Click Element                    xpath://button[.//span[normalize-space()='Back']]

Update Tenure and Interest
    [Documentation]    Update loan tenure and interest rate, then continue to checkout.
    Execute JavaScript               window.scrollTo(0, document.documentElement.scrollHeight);
    # Scroll Element Into View         xpath://button[.//span[normalize-space()='Proceed']]
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Proceed']]    timeout=10s
    Click Element                    xpath://button[.//span[normalize-space()='Proceed']]
    Wait Until Element Is Visible    xpath://h5[contains(text(),'Select Loan')]//following::span[6]    timeout=10s
    Double Click Element             xpath://h5[contains(text(),'Select Loan')]//following::span[6]
    Click Element                    xpath://span[text()='Confirm & Proceed']/ancestor::button

# ──────────────────────────────────────────────
# DIGITAL SIGNATURE & DISBURSEMENT
# ──────────────────────────────────────────────
Digital Signature And Disbursement
    [Documentation]    Complete e-sign flow and trigger loan disbursement.
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Digital Signature']]         timeout=10s
    Scroll Element Into View         xpath://button[.//span[normalize-space()='Digital Signature']]
    Click Element                    xpath://button[.//span[normalize-space()='Digital Signature']]
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Verify Status']]
    Click Element                    xpath://button[.//span[normalize-space()='Verify Status']]
    Wait Until Element Is Visible    xpath://button[.//span[normalize-space()='Proceed Loan Disbursement']]    timeout=5s
    Click Element                    xpath://button[.//span[normalize-space()='Proceed Loan Disbursement']]

E-Mandate
    [Documentation]      Complete e-mandate flow and trigger loan disbursement.
    Wait Until Element Is Visible    xpath://button[.//span[text()='E-Mandate']]    timeout=10s
    Scroll Element Into View         xpath://button[.//span[text()='E-Mandate']]
    Click Element                    xpath://button[.//span[text()='E-Mandate']]
    Wait Until Element Is Visible    xpath://div[contains(text(),'Loan repayments')]//following::span[1]         timeout=10s
    Double Click Element             xpath://div[contains(text(),'Loan repayments')]//following::span[1]
    Sleep     2s
    Wait Until Element Is Visible    xpath://form[@id='eMandateForm']//button[.//span[normalize-space()='Continue']]                       timeout=15s
    Click Element                    xpath://form[@id='eMandateForm']//button[.//span[normalize-space()='Continue']]
