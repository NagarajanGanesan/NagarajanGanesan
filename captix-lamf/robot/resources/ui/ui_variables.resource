*** Settings ***
Resource    ../variables.resource

*** Variables ***
# Application URL
${UI_URL}           http://localhost:5174/

# Login Credentials
${USERNAME}         000001
${PASSWORD}         ChangeMe_UserPass_123

# Mock OTPs (used in non-prod environments)
${LOGIN_OTP}        12345678
${EMAIL_OTP}        12345678
${CAMS_OTP}         12345
${KFIN_OTP}         123456

# Excel Data Source
${EXCEL_PATH}       ${CURDIR}\\..\\..\\data\\primary_client\\ui\\primary_client_ui_data.xlsx
${SHEET_NAME}       data

# PRIMARY_CLIENT API credentials — used to call logout API on "User already logged in"
# API_APP_CODE is the PRIMARY_CLIENT app code; API_KEY and CLIENT_ID are fetched from DB at Suite Setup
${API_APP_CODE}     22222222-3333-4444-5555-666666666666
${USER_ID}          1
${USER_ROLE}        1
${API_KEY}          1122334455667788990011223344556677889900aabbccddeeff00112233445566
${CLIENT_ID}        01ABCDEFGHIJKLMNOPQRSTUVWX
