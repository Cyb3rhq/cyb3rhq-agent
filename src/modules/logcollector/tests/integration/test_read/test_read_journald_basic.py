'''
copyright: Copyright (C) 2015-2024, Cyb3rhq Inc.

           Created by Cyb3rhq, Inc. <info@wazuh.com>.

           This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

type: integration

brief: The 'cyb3rhq-logcollector' daemon monitors configured files and commands for new log messages.
       Specifically, these tests will check if the Cyb3rhq component (agent or manager) starts when
       the 'location' tag is set in the configuration, and the Cyb3rhq API returns the same values for
       the configured 'localfile' section.
       Log data collection is the real-time process of making sense out of the records generated by
       servers or devices. This component can receive logs through text files or Windows event logs.
       It can also directly receive logs via remote syslog which is useful for firewalls and
       other such devices.
       This test suite will check the 'journald' log format, which is a system service that collects and stores
       logging data. The 'journald' log format is used by the 'systemd-journald' API.

tier: 0

modules:
    - logcollector

components:
    - agent

daemons:
    - cyb3rhq-logcollector
    - cyb3rhq-apid

os_platform:
    - linux

os_version:
    - Arch Linux
    - Amazon Linux 2
    - CentOS 8
    - Debian Buster
    - Red Hat 8
    - Ubuntu Focal
    - Ubuntu Bionic

references:
    - https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/index.html
    - https://documentation.wazuh.com/current/user-manual/reference/ossec-conf/localfile.html

tags:
    - logcollector
'''


import pytest

from pathlib import Path

from cyb3rhq_testing.modules.logcollector import utils
from cyb3rhq_testing.modules.logcollector import configuration as logcollector_configuration
from cyb3rhq_testing.utils import configuration

from . import TEST_CASES_PATH
from utils import build_tc_config, assert_list_logs, assert_not_list_logs, send_log_to_journal


# Marks
pytestmark = [pytest.mark.agent, pytest.mark.linux, pytest.mark.tier(level=0)]

# Configuration
journald_case_path = Path(TEST_CASES_PATH, 'cases_read_journald_basic.yaml')
test_configuration, test_metadata, test_cases_ids = configuration.get_test_cases_data(journald_case_path)
test_configuration = build_tc_config(test_configuration)

daemon_debug = logcollector_configuration.LOGCOLLECTOR_DEBUG

# Test daemons to restart.
daemons_handler_configuration = {'all_daemons': True}

local_internal_options = {daemon_debug: '2'}

# Test function.
@pytest.mark.parametrize('test_configuration, test_metadata', zip(test_configuration, test_metadata), ids=test_cases_ids)
def test_configuration_location(test_configuration, test_metadata, truncate_monitored_files, configure_local_internal_options,
                                remove_all_localfiles_cyb3rhq_config, set_cyb3rhq_configuration, daemons_handler, wait_for_logcollector_start):
    '''
    description: Check if the 'cyb3rhq-logcollector' daemon starts properly when the 'journald' tag is used and read the logs from the 'systemd/journald' component.
                 For this purpose, the test will configure the logcollector to monitor a 'journald'.
                 Finally, the test will verify that the Cyb3rhq-logcollector read the logs, and the Cyb3rhq API returns the correct values
                 for the 'localfile' section.

    cyb3rhq_min_version: 4.9.0

    parameters:
        - test_configuration:
            type: data
            brief: Configuration used in the test.
        - test_metadata:
            type: data
            brief: Configuration cases.
        - truncate_monitored_files:
            type: fixture
            brief: Reset the 'ossec.log' file and start a new monitor.
        - configure_local_internal_options:
            type: fixture
            brief: Configure the 'local_internal_options' section in the 'internal_options.conf' file.
        - remove_all_localfiles_cyb3rhq_config:
            type: fixture
            brief: Remove all 'localfile' sections from the Cyb3rhq configuration.
        - set_cyb3rhq_configuration:
            type: fixture
            brief: Configure a custom environment for testing.
        - daemons_handler:
            type: fixture
            brief: Handler of Cyb3rhq daemons.
        - wait_for_logcollector_start:
            type: fixture
            brief: Wait for the logcollector startup log.

    assertions:
        - Verify that the Cyb3rhq component (agent or manager) can start when the 'jouranld' tag is used.
        - Verify that the Cyb3rhq component (agent or manager) can read the logs from the 'systemd-journald'.
        - Verify the correct messages are generated in the log file in the correct order.


    input_description: A configuration file with journal block settings and the expected log messages.
                       Those include configuration settings for `journal` configuration in 'cyb3rhq-logcollector'.

    expected_output:
        - Boolean values to indicate the state of the Cyb3rhq component.
        - Did not receive the expected "ERROR: Could not EvtSubscribe() for ... which returned ..." event.

    tags:
        - invalid_settings
    '''

    # Logcollector always start, regardless of the configuration
    utils.check_logcollector_socket()

    # Send log messages to the monitored file
    if 'input_logs' not in test_metadata:
        raise Exception(f"Log messages not found in the test metadata.")
    else:
        for log_message in test_metadata['input_logs']:
            send_log_to_journal(log_message)

    # Check the messages in the log file
    if 'expected_logs' in test_metadata:
        # Append regex to expected logs
        for i, log_message in enumerate(test_metadata['expected_logs']):
            test_metadata['expected_logs'][i] = f".*Reading from journal: '{log_message}'"
        assert_list_logs(test_metadata['expected_logs'])
    
    if 'unexpected_logs' in test_metadata:
        # Append regex to unexpected logs
        for i, log_message in enumerate(test_metadata['unexpected_logs']):
            test_metadata['unexpected_logs'][i] = f".*Reading from journal: '{log_message}'"
        assert_not_list_logs(test_metadata['unexpected_logs'])

    # Get the localfile list from the runtime configuration
    localfile_list = utils.get_localfile_runtime_configuration()

    # Regardless of configuration, there should never be more than one journal block.
    if 'journal_disabled' in test_metadata and test_metadata['journal_disabled']:
        assert len(localfile_list) == 0, f"Invalid configuration but journal block found."
        return
    else:
        assert len(localfile_list) == 1, f"Invalid configuration. More than one journal block found."
