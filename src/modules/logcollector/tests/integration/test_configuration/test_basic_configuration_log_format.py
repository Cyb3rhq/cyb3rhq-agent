'''
copyright: Copyright (C) 2015-2024, Cyb3rhq Inc.

           Created by Cyb3rhq, Inc. <info@wazuh.com>.

           This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

type: integration

brief: The 'cyb3rhq-logcollector' daemon monitors configured files and commands for new log messages.
       Specifically, these tests will check if the logcollector detects invalid values for
       the 'log_format' tag and the Cyb3rhq API returns the same values for the configured
       'localfile' section. They also check some special aspects when macOS is used.
       Log data collection is the real-time process of making sense out of
       the records generated by servers or devices. This component can receive logs through
       text files or Windows event logs. It can also directly receive logs via remote syslog
       which is useful for firewalls and other such devices.

components:
    - logcollector

suite: configuration

targets:
    - agent

daemons:
    - cyb3rhq-logcollector
    - cyb3rhq-apid

os_platform:
    - linux
    - macos
    - windows

os_version:
    - Arch Linux
    - Amazon Linux 2
    - Amazon Linux 1
    - CentOS 8
    - CentOS 7
    - Debian Buster
    - Red Hat 8
    - macOS Catalina
    - macOS Server
    - Ubuntu Focal
    - Ubuntu Bionic
    - Windows 10
    - Windows Server 2019
    - Windows Server 2016

references:
    - https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/index.html
    - https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/localfile.html#log-format
    - https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/localfile.html#location

tags:
    - logcollector_configuration
'''

import pytest, sys, os, tempfile, re
import subprocess as sb

from pathlib import Path

from cyb3rhq_testing.constants.paths.logs import CYB3RHQ_LOG_PATH, MACOS_LOG_COMMAND_PATH
from cyb3rhq_testing.constants.platforms import WINDOWS, MACOS
from cyb3rhq_testing.constants.daemons import LOGCOLLECTOR_DAEMON
from cyb3rhq_testing.modules.logcollector import configuration as logcollector_configuration
from cyb3rhq_testing.modules.logcollector import patterns, PREFIX
from cyb3rhq_testing.tools.monitors import file_monitor
from cyb3rhq_testing.utils import callbacks, configuration
from cyb3rhq_testing.utils.services import control_service
from cyb3rhq_testing.utils.file import truncate_file

from . import TEST_CASES_PATH, CONFIGURATIONS_PATH


LOG_COLLECTOR_GLOBAL_TIMEOUT = 40


# Marks
pytestmark = [pytest.mark.agent, pytest.mark.linux, pytest.mark.win32, pytest.mark.darwin, pytest.mark.tier(level=0)]

# Configuration

default_config_path = Path(CONFIGURATIONS_PATH, 'cyb3rhq_basic_configuration_log_format.yaml')
default_cases_path = Path(TEST_CASES_PATH, 'cases_basic_configuration_log_format.yaml')

macos_duplicated_config_path = Path(CONFIGURATIONS_PATH, 'cyb3rhq_duplicated_macos_configuration.yaml')
macos_duplicated_cases_path = Path(TEST_CASES_PATH, 'cases_basic_configuration_log_format_macos_duplicated.yaml')

macos_no_defined_config_path = Path(CONFIGURATIONS_PATH, 'cyb3rhq_no_defined_location_macos_configuration.yaml')
macos_no_defined_cases_path = Path(TEST_CASES_PATH, 'cases_basic_configuration_log_format_macos_no_defined.yaml')

win_config_path = Path(CONFIGURATIONS_PATH, 'cyb3rhq_basic_configuration_log_format_location.yaml')
win_cases_path = Path(TEST_CASES_PATH, 'cases_basic_configuration_log_format_win.yaml')

test_configuration, test_metadata, test_cases_ids = configuration.get_test_cases_data(default_cases_path)

folder_path = tempfile.gettempdir()
location = os.path.join(folder_path, 'test.txt')
for test in test_metadata:
    if test['location'] and test['log_format'] != 'djb-multilog':
        test['location'] = re.escape(location)
for test in test_configuration:
    if test['LOCATION'] and test['LOG_FORMAT'] != 'djb-multilog':
        test['LOCATION'] = location

test_configuration = configuration.load_configuration_template(default_config_path, test_configuration, test_metadata)

test_macos_dup_configuration, test_macos_dup_metadata, test_macos_dup_cases_ids = configuration.get_test_cases_data(macos_duplicated_cases_path)
test_macos_dup_configuration = configuration.load_configuration_template(macos_duplicated_config_path, test_macos_dup_configuration, test_macos_dup_metadata)

test_macos_nodef_configuration, test_macos_nodef_metadata, test_macos_nodef_cases_ids = configuration.get_test_cases_data(macos_no_defined_cases_path)
test_macos_nodef_configuration = configuration.load_configuration_template(macos_no_defined_config_path, test_macos_nodef_configuration, test_macos_nodef_metadata)

test_win_configuration, test_win_metadata, test_win_cases_ids = configuration.get_test_cases_data(win_cases_path)
test_win_configuration = configuration.load_configuration_template(win_config_path, test_win_configuration, test_win_metadata)


if sys.platform == MACOS:
    test_configuration += test_macos_dup_configuration
    test_configuration += test_macos_nodef_configuration
    test_metadata += test_macos_dup_metadata
    test_metadata += test_macos_nodef_metadata
    test_cases_ids += test_macos_dup_cases_ids
    test_cases_ids += test_macos_nodef_cases_ids
if sys.platform == WINDOWS:
    test_configuration += test_win_configuration
    test_metadata += test_win_metadata
    test_cases_ids += test_win_cases_ids


local_internal_options = {logcollector_configuration.LOGCOLLECTOR_REMOTE_COMMANDS: '1', logcollector_configuration.LOGCOLLECTOR_DEBUG: '2'}

log_format_not_print_analyzing_info = ['command', 'full_command', 'eventlog', 'eventchannel', 'macos']

# Test daemons to restart.
daemons_handler_configuration = {'all_daemons': True}


def check_log_format_valid(test_configuration, test_metadata):
    """Check if Cyb3rhq run correctly with the specified log formats.

    Ensure logcollector allows the specified log formats. Also, in the case of the manager instance, check if the API
    answer for localfile block coincides.

    Raises:
        TimeoutError: If the "Analyzing file" callback is not generated.
        AssertError: In the case of a server instance, the API response is different that the real configuration.
    """
    cyb3rhq_log_monitor = file_monitor.FileMonitor(CYB3RHQ_LOG_PATH)

    if test_metadata['log_format'] not in log_format_not_print_analyzing_info:
        cyb3rhq_log_monitor.start(timeout=5,
                                callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_ANALYZING_FILE,
                                                   {'file': test_metadata['location']}))
        assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_ANALYZING_FILE
    elif 'command' in test_metadata['log_format']:
        if test_metadata['log_format'] == 'full_command':
            callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MONITORING_FULL_COMMAND, {
                                'command': test_metadata['command']})
        else:
            callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MONITORING_COMMAND, {
                                'command': test_metadata['command']})
        cyb3rhq_log_monitor.start(timeout=5, callback=callback)
        assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_COMMAND_MONITORING
    elif test_metadata['log_format'] == 'djb-multilog':
        cyb3rhq_log_monitor.start(timeout=5,
                                callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_DJB_PROGRAM_NAME,
                                                   {'program_name': test_metadata['location']}))
        assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_DJB_MULTILOG_NOT_PRODUCED
    elif test_metadata['log_format'] == 'macos':
        if 'location' in test_metadata and test_metadata['location'] != 'macos':
            cyb3rhq_log_monitor.start(timeout=5,
                                    callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MACOS_INVALID_LOCATION,
                                                    {'location': test_metadata['location']}))
            assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_INVALID_MACOS_VALUE
        if 'location' not in test_metadata:
            cyb3rhq_log_monitor.start(timeout=5,
                                    callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MACOS_MISSING_LOCATION))
            assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_MISSING_LOCATION_VALUE

        cyb3rhq_log_monitor.start(timeout=5,
                                callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MACOS_MONITORING_LOGS,
                                                   {'command_path': MACOS_LOG_COMMAND_PATH}))
        assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_MACOS_LOG_NOT_PRODUCED


def check_log_format_invalid(test_metadata):
    """Check if Cyb3rhq fails because a invalid frequency configuration value.

    Args:
        test_configuration (dict): Dictionary with the localfile configuration.

    Raises:
        TimeoutError: If error callback are not generated.
    """

    if test_metadata['valid_value']:
        pytest.skip('Valid values provided')

    cyb3rhq_log_monitor = file_monitor.FileMonitor(CYB3RHQ_LOG_PATH)
    log_callback = callbacks.generate_callback(patterns.LOGCOLLECTOR_INVALID_VALUE_ELEMENT,
                                                {'prefix' : PREFIX,
                                                'option': 'log_format',
                                                'value' : test_metadata['log_format']})
    cyb3rhq_log_monitor.start(timeout=5, callback=log_callback)
    assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_GENERIC_MESSAGE

    log_callback = callbacks.generate_callback(patterns.LOGCOLLECTOR_CONFIGURATION_ERROR,
                                                {'prefix' : PREFIX,
                                                 'severity' : 'ERROR',
                                                'conf_path' : "etc/ossec.conf"})
    cyb3rhq_log_monitor.start(timeout=5, callback=log_callback)
    assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_GENERIC_MESSAGE

    if sys.platform != WINDOWS:

        log_callback = callbacks.generate_callback(patterns.LOGCOLLECTOR_CONFIGURATION_ERROR,
                                                {'prefix' : PREFIX,
                                                 'severity' : 'ERROR',
                                                'conf_path' : "etc/ossec.conf"})
        cyb3rhq_log_monitor.start(timeout=5, callback=log_callback)
        assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_GENERIC_MESSAGE


def check_log_file_duplicated():
    """Check if Cyb3rhq shows a warning message when the configuration is duplicated."""
    cyb3rhq_log_monitor = file_monitor.FileMonitor(CYB3RHQ_LOG_PATH)
    cyb3rhq_log_monitor.start(timeout=LOG_COLLECTOR_GLOBAL_TIMEOUT,
                            callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_LOG_FILE_DUPLICATED))
    assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_LOG_FILE_DUPLICATED
    cyb3rhq_log_monitor.start(timeout=LOG_COLLECTOR_GLOBAL_TIMEOUT,
                            callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_MACOS_MONITORING_LOGS,
                                                                 {'command_path': MACOS_LOG_COMMAND_PATH}))
    assert (cyb3rhq_log_monitor.callback_result != None), patterns.ERROR_ANALYZING_MACOS


# Test function.
@pytest.mark.parametrize('test_configuration, test_metadata', zip(test_configuration, test_metadata), ids=test_cases_ids)
def test_log_format(test_configuration, test_metadata, configure_local_internal_options, truncate_monitored_files,
                    set_cyb3rhq_configuration, daemons_handler_module, stop_logcollector):
    '''
    description: Check if the 'cyb3rhq-logcollector' daemon detects invalid configurations for the 'log_format' tag.
                 It also checks some special aspects when using macOS. For this purpose, the test will set a
                 'localfile' section using valid/invalid values for the 'log_format' tag. Then, it will check if
                 an error event is generated when using an invalid value. If macOS is the host system, the test
                 will verify that only one configuration block is used, and the 'location' tag allows invalid values.
                 Finally, the test will verify that the Cyb3rhq API returns the same values for the 'localfile' section
                 that the configured one.

    cyb3rhq_min_version: 4.4.0

    tier: 0

    parameters:
        - test_configuration:
            type: data
            brief: Configuration used in the test.
        - test_metadata:
            type: data
            brief: Configuration cases.
        - configure_local_internal_options:
            type: fixture
            brief: Configure the Cyb3rhq local internal options.
        - truncate_monitored_files:
            type: fixture
            brief: Reset the 'ossec.log' file and start a new monitor.
        - set_cyb3rhq_configuration:
            type: fixture
            brief: Configure a custom environment for testing.
        - daemons_handler_module:
            type: fixture
            brief: Handler of Cyb3rhq daemons.
        - stop_logcollector:
            type: fixture
            brief: Stop logcollector daemon.

    assertions:
        - Verify that the logcollector generates error events when using invalid values for the 'log_format' tag.
        - Verify that the logcollector accepts invalid values for the 'location' tag when 'macos' log format is set.
        - Verify that the logcollector uses the default macOS value for the 'location' tag when it is not defined.
        - Verify that the logcollector allows only one macOS configuration section.
        - Verify that the Cyb3rhq API returns the same values for the 'localfile' section as the configured one.


    input_description: A configuration templates (test_basic_configuration_log_format) are contained in externals
                       YAML files (cyb3rhq_basic_configuration.yaml, cyb3rhq_duplicated_macos_configuration.yaml, and
                       cyb3rhq_no_defined_location_macos_configuration.yaml). Those templates are combined with
                       different test cases defined in the module. Those include configuration settings for
                       the 'cyb3rhq-logcollector' daemon.

    expected_output:
        - r'Analyzing file.*'
        - r'INFO: Monitoring .* of command.*'
        - r'INFO: Using program name .* for DJB multilog file.*'
        - r'Invalid value for element .*'
        - r'Configuration error at .*'
        - r"Can't add more than one 'macos' block"
        - r'Monitoring macOS logs with'
        - r"Invalid location value .* when using 'macos' as 'log_format'. Default value will be used."
        - r"Missing 'location' element when using 'macos' as 'log_format'. Default value will be used."

    tags:
        - invalid_settings
        - logs
    '''

    if test_metadata['valid_value']:
        control_service('start', daemon=LOGCOLLECTOR_DAEMON)
        if 'location1' in test_metadata:
            check_log_file_duplicated()
        else:
            check_log_format_valid(test_configuration, test_metadata)
    else:
        if sys.platform == WINDOWS:
            pytest.xfail("Windows agent allows invalid localfile configuration:\
                          https://github.com/cyb3rhq/cyb3rhq/issues/10890")
            expected_exception = ValueError
        else:
            expected_exception = sb.CalledProcessError

        with pytest.raises(expected_exception):
            control_service('start', daemon=LOGCOLLECTOR_DAEMON)
        check_log_format_invalid(test_metadata)
