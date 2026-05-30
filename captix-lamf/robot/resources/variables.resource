*** Settings ***
Resource    imports.resource

*** Variables ***
# ─── Base Configuration ───────────────────────────────────────────────────────
${ENV}                              dev
${primary_client_schemeName}        primary_scheme
${partner_client_schemeName}        partner_scheme
${qa_schemeName}                    qa

${PRIMARY_CLIENT_URL}               https://api-dev.example.com
${PARTNER_CLIENT_URL}               https://partner-api-dev.example.com
${QA_URL}                           https://qa-api-dev.example.com

&{DB_CONFIGS}      dev=&{DEV_DB}

&{Dev_DB}          name=apicore     Username=apicore_app   Password=ChangeMe_DbPass_123      Host=192.0.2.10    Port=5432     db_charset=None

# ─── Per-Suite HMAC Credentials ───────────────────────────────────────────────
# build_header.resource picks the right pair via ${scheme}.
# Each suite's Suite Setup sets ${scheme}=primary_client or ${scheme}=partner_client; default below is PRIMARY_CLIENT.
${primary_client-api-key}      0a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff0
${primary_client-client-id}    01ABCDEF0123456789ABCDEFGH
${partner_client-api-key}      f0eeddccbbaa99887766554433221100ffeeddccbb9988776655443322110011
${partner_client-client-id}    01ZYXWVU9000000001ZYXWVUTS

${scheme}                  primary_client

# ─── Suite-scoped Auth State ──────────────────────────────────────────────────
# Set during Suite Setup Auth; defaults below mirror build_header.resource.
# ${suite_cookies}       ${NONE}
# ${suite_client_Id}     ${NONE}
# ${suite_api_key}       ${NONE}
# ${suite_app_code}      ${NONE}

# Status code
${Created_code}=                201
${expected_code}=               200
${incorrect_expected_code}=     400
${notFound_exp_code}=           404
${server_err_code}              500
${unauthorized_code}=           401

# Validations and Regex
${pan_regex_pattern}=           ^[A-Z]{5}[0-9]{4}[A-Z]{1}$
${Acc_regex_pattern}=           ^[0-9]{8,17}$
${cin_regex_pattern}=           ^[L|U]{1}[0-9]{5}[A-Za-z]{2}[0-9]{4}[A-Za-z]{3}[0-9]{6}$
${gst_regex_pattern}=           ^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$
${Aadhar_regex_pattern}         ^[2-9]{1}[0-9]{3}\\s[0-9]{4}\\s[0-9]{4}$
${ifsc_regex_pattern}=          ^[A-Z]{4}0[A-Z0-9]{6}$
${pin_regex_pattern}            ^[1-9]{1}[0-9]{2}\s[0-9]{3}$
${mobile_regex}                 ^[6-9]{1}[0-9]{9}$
${exp_name_regex}               ^[A-Za-z\\s]+$
${email_regex}                  ^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$

# Mock_Variables (PRIMARY_CLIENT defaults; PARTNER_CLIENT overrides via -v on command line if needed)
${app_code}     11111111-2222-3333-4444-555555555555
${userName}     000001
${password}     ChangeMe_UserPass_123
${login_type}   NORMAL

# Dedupe
${PAN_Number}      ABCDE1234F
${mobile_No}       9000000001
${lenderCustId}    10000001

${lenderId}             1

#LoanApp_init
${OD_productCode}       PRD0000000003
${TL_productCode}       PRD0000000004

# CAMS & KFINTECH
${CAM_source}          CAMS
${Kfintech_source}     KFINTECH
${modeOfHolding}       SINGLE
${schemeCategory}      Debt Category
${lienUnit}            100

# CodeValue
${codeValue_Id}          1

# ─── LOS - DeDupe / OTP ───────────────────────────────────────────────────────
${DEDUPE_OTP}                123456
${AD_login}                  AD
${DEDUPE_BY}                 PAN     # One of: PAN | MOBILE | LENDER_CUST_ID. Override per test file or via -v.

# ─── LOS - Loan Application ───────────────────────────────────────────────────
${productCode}                NA0000000001
${EMAIL}                      qa.user@example.com
${INVALID_PRODUCT_CODE}       NA000000000
${INVALID_LOAN_APP}           N000000028

# ─── LOS - KYC ────────────────────────────────────────────────────────────────
${AADHAAR_NO}                 999999999999
${REDIRECT_URL}               https://www.example.com
${NAME_AS_PER_PAN}            Test User
${DOB_AS_PER_PAN}             01-01-1990
${fileBase64}                 /9j/4AAQSkZJRgABAgAAAQABAAD/2wBDAAgGBgcGB
${VKYC_REF_ID}                REF0000001

# ─── LOS - Loan Update ────────────────────────────────────────────────────────
${FATHER_NAME}                Father Test User

# ─── LOS - MF Fetch / Pledge ──────────────────────────────────────────────────
${FETCH_OTP}           123456

# ─── LOS - DigiSign / Loan Submit ─────────────────────────────────────────────
${TEMPLATE_TYPE}              KFS_AND_SANCTION
${DIGISIGN_REF_ID}            DIGIB0000000008

# ─── LOS - Bank / NACH ────────────────────────────────────────────────────────
${BANK_ACCOUNT_NO}            1234567890123456
${BANK_IFSC}                  SAMP0001234
${BANK_NAME}                  Sample Bank
${BANK_ACCOUNT_TYPE}          Savings Account
${ACCOUNT_HOLDER_NAME}        Test User
${NACH_REDIRECT_URL}          https://www.example.com
${NACH_AUTH_MODE}             ${1}

# ─── CMS ──────────────────────────────────────────────────────────────────────
${LOAN_ACCOUNT_NO}            1000000000000001
${ISIN_INVOKE}                INF000A00000
${FOLIO_INVOKE}               10000001
${LIEN_MARK_REF}              10001
${LIEN_SUB_REF}               200001
${INVOKE_CRITERIA}            COLLATERAL_MARGIN
${ISIN_REVOKE}                INF000A00001
${FOLIO_REVOKE}               10000002
${LIEN_MARK_REF_REVOKE}       10002
${LIEN_SUB_REF_REVOKE}        200002

# ─── Loan Servicing ───────────────────────────────────────────────────────────
${WITHDRAWAL_AMOUNT}          5000
${LOAN_ACCOUNT_INVALID}       INVALID_LOAN_ACC_99
