*** Settings ***
Resource          ../../../resources/ui/ui_variables.resource
Resource          ../../../resources/ui/ui_keywords.resource
Suite Setup       Launch Browser
# Suite Teardown    Close All Browsers

*** Test Cases ***
PRIMARY_CLIENT OD Regression
    [Documentation]    PRIMARY_CLIENT Overdraft UI Regression reads CUSTOMER_ID / Mobile / Email
    ...                from Excel and runs the full OD flow for each row.

    Open Excel Document    ${EXCEL_PATH}    sheetname=${SHEET_NAME}

    ${customer_ids}=    Read Excel Column    1    sheet_name=${SHEET_NAME}    # Column 1 : CUSTOMER_ID
    ${mobile_nos}=      Read Excel Column    2    sheet_name=${SHEET_NAME}    # Column 2 : Mobile_No
    ${PAN_Nos}=         Read Excel Column    3    sheet_name=${SHEET_NAME}    # Column 3 : PAN Number

    FOR    ${i}    IN RANGE    0    1

        ${customer_id}=    Get From List    ${customer_ids}    ${i}
        ${mobile_no}=      Get From List    ${mobile_nos}      ${i}
        ${PAN_Number}=     Get From List    ${PAN_Nos}         ${i}

        Log To Console    \nRunning → Customer ID: ${customer_id} | Mobile: ${mobile_no} | Email: ${PAN_Number}

        ${status}    ${result}=    Run Keyword And Ignore Error
        ...    PRIMARY_CLIENT OD Flow    ${customer_id}

        IF    '${status}' == 'FAIL'
            # Always call logout API to clear the backend session
            Run Keyword And Ignore Error    Force API Logout
            # Then attempt UI logout; if it fails, navigate home so next iteration starts clean
            ${logout_status}    ${logout_msg}=    Run Keyword And Ignore Error    UI Logout    ${customer_id}
            IF    '${logout_status}' == 'FAIL'
                Log To Console    Logout failed (${logout_msg}) — navigating to home page.
                Go To    ${UI_URL}
            END

            IF    "Customer already exists" in "${result}" or "An active loan application already exists" in "${result}" or "An active loan already exists" in "${result}"
                Log To Console    Skipping Customer ${customer_id}: ${result}
                CONTINUE
            ELSE
                Fail    Testcase failed for Customer ID: ${customer_id} | Error: ${result}
            END
        END
    END


*** Keywords ***
Launch Browser
    [Documentation]    Fetch API credentials from DB, then open Chrome and navigate to the PRIMARY_CLIENT application.
    Fetch API Credentials
    Set Selenium Speed    value=0.05s
    Open Browser          ${UI_URL}    Chrome
    Maximize Browser Window

PRIMARY_CLIENT OD Flow
    [Documentation]    Executes the complete PRIMARY_CLIENT Overdraft UI flow for a single customer.
    ...                The browser must already be open and on the login page.
    [Arguments]        ${customer_id}

    # Step 1 – Login
    UI Login

    # Step 2 – Customer Verification
    Customer Verification    ${customer_id}
    Enter OTP    ${LOGIN_OTP}
    Click Element    xpath://button[@type='submit']

    # Check for "active loan already exists" toast — fail so outer loop skips to next customer
    ${active_loan}    ${_}=    Run Keyword And Ignore Error
    ...    Wait Until Element Is Visible
    ...    xpath://div[contains(@class,'ant-notification') and contains(.,'An active loan already exists')]
    ...    timeout=3s
    IF    '${active_loan}' == 'PASS'
        Fail    An active loan already exists for this customer
    END

    # Step 3 – Initiate Loan Application
    Apply OD Loan

    # Step 4 – Email OTP Verification
    Email Verification

    # Step 5 – Update Loan (purpose, etc.)
    Update Loan Application

    # Step 6 – Bank Account Integration
    Bank Integration

    # Step 7 – CAMS: Fetch → Opt MF → Pledge
    CAMS Fetch And OTP Verification
    CAMS Opt Mutual Funds
    CAMS Pledge

    # Step 8 – KFintech: Fetch → Opt MF → Pledge
    KFIN Fetch And OTP Verification
    KFIN Opt Mutual Funds
    KFIN Pledge

    # Step 9 – Checkout & Proceed
    Checkout And Proceed

    # Step 10 – Digital Signature & Disbursement
    Digital Signature And Disbursement

    Log To Console    Overdraft Loan Disbursed Successfully! Customer ID: ${customer_id}

    # Step 11 – Logout (returns browser to login page for next iteration)
    UI Logout    ${customer_id}
