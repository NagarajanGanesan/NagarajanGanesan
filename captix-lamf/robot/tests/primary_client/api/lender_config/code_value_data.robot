*** Settings ***
Resource    ../../../../resources/common.resource
Resource    00_code.robot
Resource    00_code_value.robot
Resource    00_data_points.robot

*** Test Cases ***
Config_Add
    create_code
    create_codeValue
    create_dataPoints
    