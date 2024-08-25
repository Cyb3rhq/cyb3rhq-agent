# Copyright (C) 2015, Cyb3rhq Inc.
# Created by Cyb3rhq, Inc. <info@wazuh.com>.
# This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

import os
import subprocess
from functools import lru_cache
from sys import exit


@lru_cache(maxsize=None)
def find_cyb3rhq_path() -> str:
    """
    Get the Cyb3rhq installation path.

    Returns
    -------
    str
        Path where Cyb3rhq is installed or empty string if there is no framework in the environment.
    """
    abs_path = os.path.abspath(os.path.dirname(__file__))
    allparts = []
    while 1:
        parts = os.path.split(abs_path)
        if parts[0] == abs_path:  # sentinel for absolute paths
            allparts.insert(0, parts[0])
            break
        elif parts[1] == abs_path:  # sentinel for relative paths
            allparts.insert(0, parts[1])
            break
        else:
            abs_path = parts[0]
            allparts.insert(0, parts[1])

    cyb3rhq_path = ''
    try:
        for i in range(0, allparts.index('wodles')):
            cyb3rhq_path = os.path.join(cyb3rhq_path, allparts[i])
    except ValueError:
        pass

    return cyb3rhq_path


def call_cyb3rhq_control(option: str) -> str:
    """
    Execute the cyb3rhq-control script with the parameters specified.

    Parameters
    ----------
    option : str
        The option that will be passed to the script.

    Returns
    -------
    str
        The output of the call to cyb3rhq-control.
    """
    cyb3rhq_control = os.path.join(find_cyb3rhq_path(), "bin", "cyb3rhq-control")
    try:
        proc = subprocess.Popen([cyb3rhq_control, option], stdout=subprocess.PIPE)
        (stdout, stderr) = proc.communicate()
        return stdout.decode()
    except (OSError, ChildProcessError):
        print(f'ERROR: a problem occurred while executing {cyb3rhq_control}')
        exit(1)


def get_cyb3rhq_info(field: str) -> str:
    """
    Execute the cyb3rhq-control script with the 'info' argument, filtering by field if specified.

    Parameters
    ----------
    field : str
        The field of the output that's being requested. Its value can be 'CYB3RHQ_VERSION', 'CYB3RHQ_REVISION' or
        'CYB3RHQ_TYPE'.

    Returns
    -------
    str
        The output of the cyb3rhq-control script.
    """
    cyb3rhq_info = call_cyb3rhq_control("info")
    if not cyb3rhq_info:
        return "ERROR"

    if not field:
        return cyb3rhq_info

    env_variables = cyb3rhq_info.rsplit("\n")
    env_variables.remove("")
    cyb3rhq_env_vars = dict()
    for env_variable in env_variables:
        key, value = env_variable.split("=")
        cyb3rhq_env_vars[key] = value.replace("\"", "")

    return cyb3rhq_env_vars[field]


@lru_cache(maxsize=None)
def get_cyb3rhq_version() -> str:
    """
    Return the version of Cyb3rhq installed.

    Returns
    -------
    str
        The version of Cyb3rhq installed.
    """
    return get_cyb3rhq_info("CYB3RHQ_VERSION")


# Max size of the event that ANALYSISID can handle
MAX_EVENT_SIZE = 65535
