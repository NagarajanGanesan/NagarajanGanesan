*** Settings ***
Documentation     Combined PRIMARY_CLIENT regression — branches by ${flow}.
...               - flow=OD → Overdraft API flow (default)
...               - flow=TL → Term Loan API flow
...               Auth mode driven by ${app_code}: set=LOGIN, ${NONE}=HMAC.
...               Dedupe identifier is driven by ${DEDUPE_BY}: PAN (default), MOBILE, or LENDER_CUST_ID.
...               Run examples:
...                 robot -v flow:OD TL_and_OD_flow.robot
...                 robot -v flow:TL TL_and_OD_flow.robot
...                 robot -v flow:TL -v app_code:${NONE} TL_and_OD_flow.robot
...                 robot -v flow:OD -v DEDUPE_BY:MOBILE TL_and_OD_flow.robot
...                 robot -v flow:TL -v DEDUPE_BY:LENDER_CUST_ID TL_and_OD_flow.robot
Suite Setup       Suite Setup Auth
Suite Teardown    Suite Teardown Auth
Resource          ../../../../resources/common.resource
Resource          ../../../../resources/primary_client/auth.resource
Resource          ../../../../resources/primary_client/od_keywords.resource
Resource          ../../../../resources/primary_client/tl_keywords.resource

*** Variables ***
${EXCEL_PATH}     ${CURDIR}\\..\\..\\..\\..\\data\\primary_client\\mock\\primary_client_mock_data.xlsx
${SHEET_NAME}     data
${flow}           OD
${STATUS_COL}     5     # Column used to mark PANs as USED so the next run picks a fresh one
${DEDUPE_BY}      PAN   # Which value to use for dedupe: PAN | MOBILE | LENDER_CUST_ID


*** Test Cases ***
TL and OD_flow
    [Documentation]    Runs OD or TL flow based on ${flow} variable. Picks the next fresh PAN from
    ...                Excel (first row where Status column ${STATUS_COL} is empty) and marks it
    ...                USED before running, so the same PAN is never reused across runs.

    Open Excel Document    ${EXCEL_PATH}    sheetname=${SHEET_NAME}

    ${PAN_Numbers}=        Read Excel Column    1    sheet_name=${SHEET_NAME}
    ${mobile_Nos}=         Read Excel Column    2    sheet_name=${SHEET_NAME}
    ${lender_cust_ids}=    Read Excel Column    4    sheet_name=${SHEET_NAME}
    ${Statuses}=           Read Excel Column    ${STATUS_COL}    sheet_name=${SHEET_NAME}

    FOR    ${i}    IN RANGE    0    1

        ${fresh_index}=    Find Fresh PAN Index    ${PAN_Numbers}    ${Statuses}
        ${PAN_Number}=         Get From List    ${PAN_Numbers}        ${fresh_index}
        ${mobile_No}=          Get From List    ${mobile_Nos}         ${fresh_index}
        ${lender_cust_id}=     Get From List    ${lender_cust_ids}    ${fresh_index}
        ${row_num}=            Evaluate    ${fresh_index} + 1

        ${timestamp}=      Get Current Date    result_format=%Y-%m-%d_%H-%M-%S
        Mark PAN Used      ${row_num}    USED_${flow}_${timestamp}

        Log To Console    Running flow=${flow}, PAN=${PAN_Number}, MOBILE=${mobile_No}, LENDER_CUST_ID=${lender_cust_id}, DEDUPE_BY=${DEDUPE_BY}, ExcelRow=${row_num}

        ${status}    ${result}=    Run Keyword And Ignore Error
        ...    Run Selected Flow    ${flow}    ${PAN_Number}    ${mobile_No}    ${lender_cust_id}

        IF    "Customer already exists" in "${result}" or "An active loan application already exists" in "${result}"
            Log To Console    PAN ${PAN_Number} already consumed in backend - kept marked USED. ${result}
            CONTINUE
        ELSE IF    '${status}' == 'FAIL'
            Fail    Testcase Failed for PAN ${PAN_Number} | Error: ${result}
        END

        ${Statuses}=    Read Excel Column    ${STATUS_COL}    sheet_name=${SHEET_NAME}
    END

*** Keywords ***
# ─── Fresh-PAN Picker (Excel-backed) ──────────────────────────────────────────
Find Fresh PAN Index
    [Documentation]    Returns the 0-based list index of the first PAN whose Status cell is empty/None.
    ...                Fails clearly if every PAN in the sheet is already marked USED.
    [Arguments]    ${pan_list}    ${status_list}

    ${pan_count}=      Get Length    ${pan_list}
    ${status_count}=   Get Length    ${status_list}

    FOR    ${i}    IN RANGE    0    ${pan_count}
        IF    ${i} < ${status_count}
            ${status_val}=    Get From List    ${status_list}    ${i}
        ELSE
            ${status_val}=    Set Variable    ${EMPTY}
        END
        ${status_str}=    Convert To String    ${status_val}
        ${stripped}=      Strip String    ${status_str}
        IF    '${stripped}' == '' or '${stripped}' == 'None'
            RETURN    ${i}
        END
    END
    Fail    No fresh PAN available in ${EXCEL_PATH} (column ${STATUS_COL} fully marked). Add new rows or clear the Status column.

Mark PAN Used
    [Documentation]    Writes the given status text into the Status column for the given Excel row and saves the workbook in-place.
    [Arguments]    ${row_num}    ${status_text}
    Write Excel Cell    ${row_num}    ${STATUS_COL}    ${status_text}    sheet_name=${SHEET_NAME}
    Save Excel Document    ${EXCEL_PATH}
    Log To Console    Marked Excel row ${row_num} col ${STATUS_COL} = ${status_text}

# ─── Flow Dispatcher ──────────────────────────────────────────────────────────
Run Selected Flow
    [Arguments]    ${flow}    ${PAN_Number}    ${mobile_No}    ${lender_cust_id}

    IF    '${flow}' == 'OD'
        PRIMARY_CLIENT_OD_Flow    ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    ELSE IF    '${flow}' == 'TL'
        PRIMARY_CLIENT_TL_Flow    ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    ELSE
        Fail    Invalid flow: '${flow}'. Use -v flow:OD or -v flow:TL
    END

# ─── OD Flow (Overdraft) ──────────────────────────────────────────────────────
PRIMARY_CLIENT_OD_Flow
    [Documentation]     PRIMARY_CLIENT API Regression — Overdraft
    [Arguments]         ${PAN_Number}     ${mobile_No}    ${lender_cust_id}

    ${referenceId}=           TC_02 Dedupe Check              ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    ${platformCustId}=        TC_03 Validate OTP              ${referenceId}
    TC_04 getCustomer_details    ${platformCustId}
    ${OD_productCode}=        TC_05 getProduct
    ${loanApp_No}    ${productType}=     TC_06 Create Loan Application     ${PAN_Number}    ${mobile_No}
    ${email_referId}=         TC_07 emailInitiate        ${loanApp_No}
                              TC_08 emailValidate        ${email_referId}

    TC_09 updateLoanApplication    ${loanApp_No}
    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}=    TC_10 getCust_BankDetail    ${platformCustId}
    TC_11 create_BankInt          ${loanApp_No}    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}

    ${CAMS_referFetchID}=     TC_12 CAMS_Fetch_initiate       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TC_13 CAMS Fetch Validate OTP   ${CAMS_referFetchID}
    ${CAMS_funds}=            TC_14 Eligible Holdings_CAMS    ${loanApp_No}    ${CAMS_referFetchID}
    TC_15 Opt_MF_Using_Index_CAMS    ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_No}
    ${CAMS_pledgeRefID}=      TC_16 PledgeInitiate_CAMS       ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_No}
    TC_17 PledgeValidate_CAMS    ${CAMS_pledgeRefID}

    ${KFin_referFetchID}=     TC_18 Kfintech_Fetch_initiate       ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TC_19 Kfintech Fetch Validate OTP   ${KFin_referFetchID}
    ${KFIN_funds}=            TC_20 Eligible Holdings KFINTECH    ${loanApp_No}    ${KFin_referFetchID}
    TC_21 Opt_MF_Using_Index_KFINTECH    ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_No}
    ${KFIN_pledgeRefID}=      TC_22 PledgeInitiate_KFINTECH    ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_No}
    TC_23 PledgeValidate_KFINTECH    ${KFIN_pledgeRefID}

    TC_24 DigiSign           ${loanApp_No}
    TC_25 DigiSign Status    ${loanApp_No}
    TC_26 LoanSubmit         ${loanApp_No}

# ─── TL Flow (Term Loan) ──────────────────────────────────────────────────────
PRIMARY_CLIENT_TL_Flow
    [Documentation]     PRIMARY_CLIENT API Regression — Term Loan. Uses global ${EMAIL} (no Excel column).
    [Arguments]         ${PAN_Number}     ${mobile_No}    ${lender_cust_id}

    ${referenceId}=           TL_Dedupe                          ${PAN_Number}    ${mobile_No}    ${lender_cust_id}
    ${platform_custId}=       TL_validate_OTP                    ${referenceId}
                              TL_getCustomer_details             ${platform_custId}
    ${TL_productCode}=        TL_getProduct
    ${loanApp_No}    ${loanApp_Id}    ${cust_id}=    TL_loanApplication_Init    ${TL_productCode}    ${PAN_Number}    ${mobile_No}
    ${email_referId}=         TC_07 emailInitiate        ${loanApp_No}
                              TC_08 emailValidate        ${email_referId}

    TL_updateLoanApp          ${loanApp_No}
    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}=    TL_getCust_BankDetail    ${platform_custId}
    TL_create_BankInt         ${loanApp_No}    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}

    ${CAMS_referFetchID}=     TL_CAMS_Fetch_initiate             ${TL_productCode}    ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TL_CAMS_Fetch_Validate OTP         ${CAMS_referFetchID}
    ${CAMS_funds}=            TL_Eligible Holdings_CAMS          ${loanApp_No}    ${CAMS_referFetchID}
    TL_Opt_MF_Using_Index_CAMS    ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_Id}
    ${CAMS_pledgeRefID}=      TL_PledgeInitiate_CAMS             ${CAMS_funds}    ${CAMS_referFetchID}    ${loanApp_No}
    TL_PledgeValidate_CAMS    ${CAMS_pledgeRefID}

    ${KFin_referFetchID}=     TL_Kfintech_Fetch_initiate         ${TL_productCode}    ${loanApp_No}    ${PAN_Number}    ${mobile_No}
                              TL_Kfintech_Fetch_Validate OTP     ${KFin_referFetchID}
    ${KFIN_funds}=            TL_Eligible Holdings_KFINTECH      ${loanApp_No}    ${KFin_referFetchID}
    TL_Opt_MF_Using_Index_KFINTECH    ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_Id}
    ${KFIN_pledgeRefID}=      TL_PledgeInitiate_KFINTECH         ${KFIN_funds}    ${KFin_referFetchID}    ${loanApp_No}
    TL_PledgeValidate_KFINTECH    ${KFIN_pledgeRefID}

    TL_updateLoanApp_InterestTenure    ${loanApp_No}
    TL_DigiSign               ${loanApp_No}
    TL_DigiSign_Status        ${loanApp_No}
    TL_LoanSubmit             ${loanApp_No}
    TL_mandateInt             ${loanApp_No}    ${bankAccount}    ${ifsc}    ${bankName}    ${bankAccountType}    ${accountHolderName}
    TL_mandateStatus          ${loanApp_No}
