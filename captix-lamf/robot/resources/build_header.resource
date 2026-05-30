*** Settings ***
Resource     common.resource
Library      ../libraries/SignatureHelper.py

*** Variables ***
${HMAC_KEY}            pK7vL9tQ4xWZRMn3DcViLM2pXrnHseUq3CwzKBvuT/e=

# Suite-scoped auth state — overridden at runtime by Suite Setup Auth.
# Defaults are required so $suite_app_code is referenceable even in HMAC mode (where it stays None).
${suite_app_code}      ${None}
${suite_cookies}       ${None}
${suite_client_Id}     ${None}
${suite_api_key}       ${None}

*** Keywords ***
# ─── Header Factory ───────────────────────────────────────────────────────────
Build Headers
    [Documentation]    Common headers for POST/PUT.
    ...                app_code present  → Cookie + X-CLIENT-ID + X-API-KEY + app-code
    ...                app_code absent   → X-Timestamp + X-Request-Signature + x-client-id + x-api-key
    [Arguments]    ${body}
    IF    $suite_app_code is not None
        &{headers}=    Create Dictionary
        ...    Content-Type=application/json
        ...    Cookie=${suite_cookies}
        ...    X-CLIENT-ID=${suite_client_Id}
        ...    X-API-KEY=${suite_api_key}
        ...    app-code=${suite_app_code}
    ELSE
        ${timestamp}=    SignatureHelper.Generate Timestamp
        ${json_str}=     Evaluate    json.dumps($body, separators=(',', ':'))    json
        ${signature}=    SignatureHelper.Generate Hmac Signature    ${HMAC_KEY}    ${json_str}    ${timestamp}    ${FALSE}
        &{headers}=      Create Dictionary
        ...    Content-Type=application/json
        ...    X-Timestamp=${timestamp}
        ...    X-Request-Signature=${signature}
        ...    x-client-id=${${scheme}-client-id}
        ...    x-api-key=${${scheme}-api-key}
    END
    RETURN    ${headers}

Build Get Headers
    [Documentation]    GET headers.
    ...                app_code present  → Cookie + X-CLIENT-ID + X-API-KEY + app-code
    ...                app_code absent   → X-Timestamp + X-Request-Signature + x-client-id + x-api-key
    IF    $suite_app_code is not None
        &{headers}=    Create Dictionary
        ...    Content-Type=application/json
        ...    Cookie=${suite_cookies}
        ...    X-CLIENT-ID=${suite_client_Id}
        ...    X-API-KEY=${suite_api_key}
        ...    app-code=${suite_app_code}
    ELSE
        ${timestamp}=    SignatureHelper.Generate Timestamp
        ${signature}=    SignatureHelper.Generate Hmac Signature    ${HMAC_KEY}    ${NONE}    ${timestamp}    ${TRUE}
        &{headers}=      Create Dictionary
        ...    Content-Type=application/json
        ...    X-Timestamp=${timestamp}
        ...    X-Request-Signature=${signature}
        ...    x-client-id=${${scheme}-client-id}
        ...    x-api-key=${${scheme}-api-key}
    END
    RETURN    ${headers}
