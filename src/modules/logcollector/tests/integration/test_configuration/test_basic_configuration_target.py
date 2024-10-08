'''
copyright: Copyright (C) 2015-2024, Cyb3rhq Inc.

           Created by Cyb3rhq, Inc. <info@wazuh.com>.

           This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

type: integration

brief: The 'cyb3rhq-logcollector' daemon monitors configured files and commands for new log messages.
       Specifically, these tests will check if the logcollector detects that a custom socket is
       undefined if the 'target' attribute of the 'out_format' tag has the name of an unexistent
       socket (invalid value). Log data collection is the real-time process of making sense out
       of the records generated by servers or devices. This component can receive logs through
       text files or Windows event logs. It can also directly receive logs via remote syslog
       which is useful for firewalls and other such devices.

components:
    - logcollector

suite: configuration

targets:
    - agent

daemons:
    - cyb3rhq-logcollector

os_platform:
    - linux
    - macos

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

references:
    - https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/index.html
    - https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/localfile.html#out-format

tags:
    - logcollector_configuration
'''

import pytest, sys

from pathlib import Path

from cyb3rhq_testing.constants.paths.logs import CYB3RHQ_LOG_PATH
from cyb3rhq_testing.constants.platforms import WINDOWS
from cyb3rhq_testing.constants.daemons import LOGCOLLECTOR_DAEMON
from cyb3rhq_testing.modules.logcollector import configuration as logcollector_configuration
from cyb3rhq_testing.modules.logcollector import patterns
from cyb3rhq_testing.modules.logcollector import utils
from cyb3rhq_testing.tools.monitors import file_monitor
from cyb3rhq_testing.utils import callbacks, configuration
from cyb3rhq_testing.utils.services import control_service
from cyb3rhq_testing.utils.file import truncate_file

from . import TEST_CASES_PATH, CONFIGURATIONS_PATH


# Marks
pytestmark = [pytest.mark.agent, pytest.mark.linux, pytest.mark.darwin, pytest.mark.tier(level=0)]

# Configuration
cases_path = Path(TEST_CASES_PATH, 'cases_basic_configuration_target.yaml')
config_path = Path(CONFIGURATIONS_PATH, 'cyb3rhq_basic_configuration_target.yaml')
local_internal_options = {logcollector_configuration.LOGCOLLECTOR_DEBUG: '2'}

test_configuration, test_metadata, test_cases_ids = configuration.get_test_cases_data(cases_path)

test_configuration = configuration.load_configuration_template(config_path, test_configuration, test_metadata)

# Test daemons to restart.
daemons_handler_configuration = {'all_daemons': True}


@pytest.mark.parametrize('test_configuration, test_metadata', zip(test_configuration, test_metadata), ids=test_cases_ids)
def test_configuration_target(test_configuration, test_metadata, set_cyb3rhq_configuration, configure_local_internal_options, daemons_handler_module, stop_logcollector):
    '''
    description: Check if the 'cyb3rhq-logcollector' daemon detects invalid configurations for the 'target' attribute
                 of the 'out_format' tag. For this purpose, the test will set a 'socket' section to specify a custom
                 socket, and a 'localfile' section using valid/invalid values for that attribute. Then, it will check
                 if an event indicating that the socket is not defined when using an invalid value, or if an event
                 indicating that the socket is detected when using valid ones. Finally, the test will verify that
                 the Cyb3rhq API returns the same values for the 'localfile' section that the configured one.

    cyb3rhq_min_version: 4.2.0

    tier: 0

    parameters:
        - test_configuration:
            type: data
            brief: Configuration used in the test.
        - test_metadata:
            type: data
            brief: Configuration cases.
        - set_cyb3rhq_configuration:
            type: fixture
            brief: Configure a custom environment for testing.
        - configure_local_internal_options:
            type: fixture
            brief: Configure the Cyb3rhq local internal options.
        - daemons_handler_module:
            type: fixture
            brief: Handler of Cyb3rhq daemons.
        - stop_logcollector:
            type: fixture
            brief: Stop logcollector daemon.

    assertions:
        - Verify that the logcollector detects undefined sockets when using invalid values for the 'target' attribute.
        - Verify that the logcollector detects custom sockets when using valid values for the 'target' attribute.
        - Verify that the Cyb3rhq API returns the same values for the 'localfile' section as the configured one.

    input_description: A configuration template (test_basic_configuration_target) is contained in an external
                       YAML file (cyb3rhq_basic_configuration.yaml). That template is combined with different
                       test cases defined in the module. Those include configuration settings
                       for the 'cyb3rhq-logcollector' daemon.

    expected_output:
        - r'Socket target for .* -> .*'
        - r'Socket .* for .* is not defined."

    tags:
        - invalid_settings
    '''

    control_service('start', daemon=LOGCOLLECTOR_DAEMON)

    callback = None
    assert_error = None
    if test_metadata['valid_value']:
        callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_SOCKET_TARGET_VALID, {
                              'location': test_metadata['location'],
                              'socket_name': test_metadata['target']
                          })
        assert_error = patterns.ERROR_TARGET_SOCKET
    else:
        callback=callbacks.generate_callback(patterns.LOGCOLLECTOR_SOCKET_TARGET_NOT_DEFINED, {
                              'socket_name': test_metadata['target'],
                              'location': test_metadata['location']
                          })
        assert_error = patterns.ERROR_TARGET_SOCKET_NOT_FOUND

    cyb3rhq_log_monitor = file_monitor.FileMonitor(CYB3RHQ_LOG_PATH)
    cyb3rhq_log_monitor.start(callback, timeout=10)
    assert cyb3rhq_log_monitor.callback_result, assert_error

    if test_metadata['valid_value'] and sys.platform != WINDOWS:
        utils.check_logcollector_socket()
        utils.validate_test_config_with_module_config(test_configuration=test_configuration)
