*** Settings ***
Resource      ../../../../resources/common.resource

*** Variables ***
#Partner-product configuration
${appcode_Status}   true

#Variable for individual run
# ${service_count}    
${decryp}           False
${rateLimit}        30
${periodSec}        10

#Login
${app_code}        55555555-6666-7777-8888-999999999999
${client_Id}       01CHANNELMAPTEST1234567890
${api_key}         33445566778899aabbccddeeff00112233445566778899aabbccddeeff001122

#ChannelMap_appCode
${channelMap_app}     66666666-7777-8888-9999-aaaaaaaaaaaa

#Create_User
${userName}        admin
${password}        ChangeMe_AdminPass_123
${email}           qa.user@example.com
${loginType}       NORMAL

#Create_Role      
${role_Id}         ${1}

#Create_Permission

${application_Id}         ${1} 
${EXCEL_PATH}             ${CURDIR}\\..\\..\\..\\..\\data\\primary_client\\gateway\\PARTNER_CLIENT_Auth_Permission.xlsx
${SHEET_NAME}             PARTNER_CLIENT_Permission     #PARTNER_CLIENT_API

*** Test Cases ***
Create for test
    ${cookies}     ${client_Id}     ${api_key}     ${app_code}      Login as user 
    02_Partner_product_config_Reg     ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    03_Channel_Mapping_Reg       ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    Refresh              ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    Refresh_route        ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    ${permission_id's}    04_Create Permission         ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    05_permissionRole_Mapping    ${cookies}     ${client_Id}     ${api_key}     ${app_code}    ${permission_id's}  
    06_Logout Admin    ${cookies}     ${client_Id}     ${api_key}     ${app_code}

*** Keywords ***
Login as user    
    [Documentation]    Auth login test to verify the created user
    Create Session     user_login     url=${PRIMARY_CLIENT_URL}     verify=true

    ${db}=    Get From Dictionary       ${DB_CONFIGS}    ${ENV}
    Connect To Database    psycopg2     ${db}[name]      ${db}[Username]     ${db}[Password]     ${db}[Host]     ${db}[Port]    None
    ${access_token}     Query     SELECT api_key, client_id FROM ${primary_client_schemeName}.partner_product_config WHERE app_code = '${app_code}';

    ${key&Id}      Get From List     ${access_token}    0
    ${api_key}     Get From List     ${key&Id}          0
    ${client_Id}   Get From List     ${key&Id}          1
    Log  clientId: ${client_Id}
    Set Suite Variable    ${api_key}
    Set Suite Variable    ${client_Id}

    Disconnect From Database

    ${headers}         Create Dictionary    Content-Type=application/json
    ...    X-CLIENT-ID=${client_Id}
    ...    X-API-KEY=${api_key}
    ...    app-code=${app_code}
    ${body}    Create Dictionary
    ...        username=${userName}
    ...        userpassword=${password}
    ...        login_type=AD
    ${response}        POST On Session      user_login     /api/v1/auth/login     json=${body}     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}

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

    Log    ${access_token}
    Log    ${refresh_token}

    ${cookies}    Set Variable    ${app_code}_x-access-token=${access_token}; ${app_code}_x-refresh-token=${refresh_token}; ${app_code}_user_id=${userId}; ${app_code}_user_roles=${userRole}

    Log To Console     TC_01: ${user_name} ${msg}

    RETURN     ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${branchCode}

02_Partner_product_config_Reg
    [Arguments]     ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]    create partner product config using app_code
    Create Session     product_config     url=${PRIMARY_CLIENT_URL}     verify=true
    ${exp_date}     Compute Expiry Date
    ${body}    Create Dictionary
    ...        app_code_creation=${True}
    ...        expiry_date=${exp_date}
    ${headers}         Create Dictionary    Content-Type=application/json     
    ...    app-code=${app_code}
    ...    X-CLIENT-ID=${client_Id}     
    ...    X-API-KEY=${api_key} 
    ${response}        POST On Session      product_config     /api/v1/gateway/partner-product-config     json=${body}     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}     
    ${code}            Get Value From Json       ${json_data}     data
    ${get_appCode}     Get From List     ${code}     0
    ${app_code}=       Fetch From Right    ${get_appCode}    appCode:${SPACE}

    Log To Console     App Code: ${app_code}
    
    ${db}=    Get From Dictionary    ${DB_CONFIGS}    ${ENV}
    Connect To Database    psycopg2     ${db.name}     ${db.Username}     ${db.Password}     ${db.Host}     ${db.Port}    None
    ${access_token}     Query     SELECT api_key, client_id FROM ${primary_client_schemeName}.partner_product_config WHERE app_code = '${app_code}'; 

    ${key&Id}      Get From List     ${access_token}    0
    ${api_key}     Get From List     ${key&Id}          0
    ${client_Id}   Get From List     ${key&Id}          1
    Log  clientId: ${client_Id}     
    Set Suite Variable    ${api_key}
    Set Suite Variable    ${client_Id}
    Disconnect From Database

    RETURN     ${client_Id}     ${api_key}    ${app_code}

03_Channel_Mapping_Reg
    [Arguments]        ${cookies}     ${client_Id}     ${api_key}     ${app_code}     
    [Documentation]    channel-mapping rate limit check
    Create Session     create_channelMap     url=${PRIMARY_CLIENT_URL}

    # ${channelMap_ids}     Create List       #Creating empty list to store channel mapping ids

    ${channel_id's}    Create List
    ...    1    2    3    4    5    6    7    8    9    10
    ...    11    12    13    14    15    16    17    18    19    20
    ...    21    22    23    24    25    26    27    28    29    30
    ...    31    32    33    34    35    36    37    38    39    40
    ...    41    42    43    44    45    46    47    48    49    50
    ...    51    52    53    54    55    56    57    58    59    60
    ...    61    62    63    64    65    66    67    68    69    70
    ...    71    72    73    74    75    76    77    78    79    80
    ...    81    82    83    84    85    86    87    88    89    90
    ...    91    92    93    94    95    96    97    98    99    100
    ...    101   102   103    104    105    106    107    108    109    110
    ...    111   112   113    114    115    116    117    118    119    120
    ...    121   122   123    124    125    126    127    128    129    130
    ...    131   132   133    134    135    136    137    138    139    140
    ...    141   142    143    144    145    146    147    148    149    150
    ...    151   152    153    154    155    156    157    158    159    160
    ...    161   162    163    164    165    166    167    168    169    170
    ...    171   172    173    174    175    176    177    178    179    180
    ...    181   182    183    184    185    186    187    188    189

        FOR    ${i}    IN RANGE    189
            ${channel_id}    Get From List      ${channel_id's}    ${i}

            ${body}    Create Dictionary
            ...        api_channel_id=${channel_id}
            # ...        app_code=${channelMap_app}
            ...        product_id=1
            ...        decryption_enabled=${decryp}
            ...        rate_limit=${rateLimit}
            ...        period_seconds=${periodSec}

            ${headers}         Create Dictionary    Content-Type=application/json
             ...    Cookie=${cookies}
             ...    X-CLIENT-ID=${client_Id}     
             ...    X-API-KEY=${api_key}     
             ...    app-code=${app_code}

            ${response}        POST On Session      create_channelMap     /api/v1/gateway/channel-mapping     json=${body}     headers=${headers}
            ${status_code}=    Convert To String    ${response.status_code}
            Should Be Equal    ${status_code}       ${expected_code}

            ${json_data}          Convert String To Json    ${response.content}     
            ${id}                 Get Value From Json     ${json_data}     data.api_channel_mapping_id
            ${channelMap_id}      Get From List           ${id}             0
            
            ${limit}              Get Value From Json     ${json_data}     data.rate_limit
            ${rateLimit}          Get From List           ${limit}         0

        END

        Log To Console     03_Channel_Mapping_Reg: Channel mapping created successfully for all channels with rate limit ${rateLimit}.

04_Create Permission
    [Arguments]            ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]        Read data from excel and create channels dynamically
   
    Create Session     create_permission     url=${PRIMARY_CLIENT_URL}
    ${headers}         Create Dictionary    Content-Type=application/json
             ...    Cookie=${cookies}
             ...    X-CLIENT-ID=${client_Id}     
             ...    X-API-KEY=${api_key}     
             ...    app-code=${app_code}

    Open Excel Document    ${EXCEL_PATH}    sheetname=${SHEET_NAME}
    ${api_names}=     Read Excel Column    1    sheet_name=${SHEET_NAME}       #permission_name is in column 0
    ${api_paths}=     Read Excel Column    2    sheet_name=${SHEET_NAME}       #resource_path is in column 1
    ${api_methods}=   Read Excel Column    3    sheet_name=${SHEET_NAME}       #http_method is in column 2

    ${name_count}      Get Length    ${api_names}
    ${path_count}      Get Length    ${api_paths}
    ${method_count}    Get Length    ${api_methods}
    Log To Console     permission_create count: ${path_count}

    ${permission_id's}=    Create List    #Creating a empty channel id list to store channel ids

        FOR    ${i}    IN RANGE    ${path_count}
            ${api_name}=      Get From List    ${api_names}      ${i}
            ${api_path}=      Get From List    ${api_paths}      ${i}
            ${api_method}=    Get From List    ${api_methods}    ${i}

            ${body}    Create Dictionary
            ...        application_id=${application_Id}
            ...        permission_name=partner_client_${api_name}
            ...        resource_path=${api_path}
            ...        http_method=${api_method}

            # Log To Console     Payload: ${body}
            ${response}        POST On Session      create_permission     /api/v1/auth/permission     json=${body}     headers=${headers}
            ${status_code}=    Convert To String    ${response.status_code}
            Should Be Equal    ${status_code}       ${expected_code}
            ${json_data}       Convert String To Json    ${response.content}  
            ${Id}              Get Value From Json       ${json_data}     data.permissionId
            ${perm_Id}         Get From List         ${Id}          0

            Append To List     ${permission_id's}    ${perm_Id}
        END
        Log    Permission IDs: ${permission_id's}

        Log To Console    05_Create Permission: Permissions created successfully
        RETURN    ${permission_id's}

05_permissionRole_Mapping
    [Arguments]        ${cookies}     ${client_Id}     ${api_key}     ${app_code}     ${permission_id's}
    [Documentation]    Map permission and role using their ids
   
    Create Session     permission_role_mapping     url=${PRIMARY_CLIENT_URL}
    
    ${headers}         Create Dictionary    Content-Type=application/json
    ...    Cookie=${cookies}
    ...    X-CLIENT-ID=${client_Id}     
    ...    X-API-KEY=${api_key}     
    ...    app-code=${app_code}

    #Database Connection and get details for Json payload
    # ${db}=    Get From Dictionary    ${DB_CONFIGS}    ${ENV}
    # Connect To Database    psycopg2     ${db.name}     ${db.Username}     ${db.Password}     ${db.Host}     ${db.Port}    None    
    # ${permission_table}       Query     SELECT count(*) FROM ${primary_client_schemeName}.permissions;
    # ${id}                     Evaluate    [item[0] for item in ${permission_table}]
    # ${permissionId_count}     Get From List    ${id}    0
    # Disconnect From Database
        ${permissionId_count}     Get Length    ${permission_id's}

        # ${permission_ids}    Create List
        # ...    185    186    187    188    189    190
        # ...    191    192    193    194    195    196
        # ...    197    198    199    200    201    202
        # ...    203    204    205    206    207    208
        # ...    209    210

        FOR    ${i}    IN RANGE    ${permissionId_count}
            
            ${permission_Id}    Get From List      ${permission_id's}    ${i}

            ${body}    Create Dictionary

            ...        role_id=${${role_Id}}
            ...        permission_id=${${permission_Id}}

            ${response}        POST On Session      permission_role_mapping     /api/v1/auth/mapping/role-permission     json=${body}     headers=${headers}
            ${status_code}=    Convert To String    ${response.status_code}
            Should Be Equal    ${status_code}       ${expected_code}
            ${json_data}       Convert String To Json    ${response.content}     
            ${message}         Get Value From Json       ${json_data}     status.message
            ${msg}             Get From List             ${message}    0
        END
        Log To Console    09_permissionRole_Mapping: ${msg} for all permissions
    
06_Logout Admin
    [Arguments]          ${cookies}     ${client_Id}     ${api_key}     ${app_code}
    [Documentation]       User_logout
    
    Create Session        logout     url=${PRIMARY_CLIENT_URL}
    ${headers}            Create Dictionary    Content-Type=application/json
        ...    Cookie=${cookies}
        ...    x-client-id=${client_Id}     
        ...    x-api-key=${api_key}     
        ...    app-code=${app_code}
    ${response}        GET On Session        logout     /api/v1/auth/logout     headers=${headers}
    ${status_code}=    Convert To String    ${response.status_code}
    Should Be Equal    ${status_code}       ${expected_code}
    ${json_data}       Convert String To Json    ${response.content}
    ${status_msg}      Get Value From Json    ${json_data}    status.message
    ${msg}     Get From List    ${status_msg}    0 
    Log To Console    ${userName}: ${msg}  