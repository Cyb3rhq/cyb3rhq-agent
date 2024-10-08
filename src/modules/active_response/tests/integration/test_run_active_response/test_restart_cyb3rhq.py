'''
copyright: Copyright (C) 2015-2024, Cyb3rhq Inc.

           Created by Cyb3rhq, Inc. <info@wazuh.com>.

           This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

type: integration

brief: Active responses execute a script in response to the triggering of specific alerts based
       on the alert level or rule group. These tests will check if the 'active responses',
       which are executed by the 'cyb3rhq-execd' daemon via scripts, run correctly.

components:
    - execd

suite: execd

targets:
    - agent

daemons:
    - cyb3rhq-analysisd
    - cyb3rhq-execd

os_platform:
    - linux
    - Windows

os_version:
    - Arch Linux
    - Amazon Linux 2
    - Amazon Linux 1
    - CentOS 8
    - CentOS 7
    - Debian Buster
    - Red Hat 8
    - Ubuntu Focal
    - Ubuntu Bionic
    - Windows 11
    - Windows 10
    - Windows Server 2019
    - Windows Server 2016

references:
    - https://documentation.wazuh.com/current/user-manual/capabilities/active-response/#active-response
'''
import sys
import pytest

from pathlib import Path

from cyb3rhq_testing.constants.paths.logs import ACTIVE_RESPONSE_LOG_PATH, CYB3RHQ_LOG_PATH
from cyb3rhq_testing.constants.platforms import WINDOWS
from cyb3rhq_testing.modules.execd.active_response.patterns import ACTIVE_RESPONSE_RESTART_CYB3RHQ
from cyb3rhq_testing.modules.agentd.configuration import AGENTD_WINDOWS_DEBUG
from cyb3rhq_testing.modules.execd.configuration import EXECD_DEBUG
from cyb3rhq_testing.modules.execd.patterns import EXECD_SHUTDOWN_RECEIVED
from cyb3rhq_testing.tools.monitors.file_monitor import FileMonitor
from cyb3rhq_testing.utils.callbacks import generate_callback
from cyb3rhq_testing.utils.configuration import get_test_cases_data, load_configuration_template

from . import CONFIGS_PATH, TEST_CASES_PATH


# Set pytest marks.
pytestmark = [pytest.mark.agent, pytest.mark.linux, pytest.mark.win32, pytest.mark.tier(level=1)]

# Cases metadata and its ids.
cases_path = Path(TEST_CASES_PATH, 'cases_execd_restart.yaml')
config_path = Path(CONFIGS_PATH, 'config_run_active_response.yaml')
test_configuration, test_metadata, cases_ids = get_test_cases_data(cases_path)
test_configuration = load_configuration_template(config_path, test_configuration, test_metadata)

# Test internal options and configurations.
local_internal_options = {AGENTD_WINDOWS_DEBUG if sys.platform == WINDOWS else EXECD_DEBUG: '2'}
daemons_handler_configuration = {'all_daemons': True}
ar_conf = 'restart-cyb3rhq0 - restart-cyb3rhq - 0\nrestart-cyb3rhq0 - restart-cyb3rhq.exe - 0'


# Test Function.
@pytest.mark.parametrize('test_configuration, test_metadata',  zip(test_configuration, test_metadata), ids=cases_ids)
def test_execd_restart(test_configuration, test_metadata, configure_local_internal_options, truncate_monitored_files,
                       set_cyb3rhq_configuration, configure_ar_conf, remoted_simulator, authd_simulator,
                       daemons_handler, send_execd_message):
    '''
    description: Check if 'restart-cyb3rhq' command of 'active response' is executed correctly.
                 For this purpose, a simulated server is used, from which the active response is sent.
                 This response includes the order to restart the Cyb3rhq agent, which must restart after
                 receiving this response.

    cyb3rhq_min_version: 4.2.0

    tier: 1

    parameters:
        - test_metadata:
            type: dict
            brief: Test case metadata.
        - truncate_monitored_files:
            type: fixture
            brief: Truncate all the log files and json alerts files before and after the test execution.
        - configure_local_internal_options:
            type: fixture
            brief: Configure the Cyb3rhq local internal options.
        - configure_ar_conf:
            type: fixture
            brief: Set the Active Response configuration.
        - remoted_simulator:
            type: fixture
            brief: Starts an RemotedSimulator instance for the test function.
        - authd_simulator:
            type: fixture
            brief: Starts an AuthdSimulator instance for the test function.
        - daemons_handler:
            type: fixture
            brief: Handler of Cyb3rhq daemons.
        - send_execd_message:
            type: fixture
            brief: Send an execd message to the agent using RemotedSimulator.

    assertions:
        - Check the expected error is raised when it supposed to fail.
        - Check the execd shutdown log is raised.
        - Check the restart-cyb3rhq program is used.
    input_description:
        - The `cases_execd_restart.yaml` file provides the test cases.
    '''
    ar_monitor = FileMonitor(ACTIVE_RESPONSE_LOG_PATH)
    cyb3rhq_log_monitor = FileMonitor(CYB3RHQ_LOG_PATH)

    if error_message := test_metadata.get('expected_error'):
        callback = generate_callback(error_message)
        ar_monitor.start(callback=callback)
        assert ar_monitor.callback_result, 'AR `cyb3rhq-restart` did not fail.'
        return

    cyb3rhq_log_monitor.start(callback=generate_callback(EXECD_SHUTDOWN_RECEIVED))
    assert cyb3rhq_log_monitor.callback_result, 'Execd `shutdown` log not raised.'

    ar_monitor.start(callback=generate_callback(ACTIVE_RESPONSE_RESTART_CYB3RHQ))
    assert ar_monitor.callback_result, 'AR `restart-cyb3rhq` program not used.'
