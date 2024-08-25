# Copyright (C) 2015, Cyb3rhq Inc.
# Created by Cyb3rhq, Inc. <info@wazuh.com>.
# This program is free software; you can redistribute it and/or modify it under the terms of GPLv2

import os
from functools import lru_cache


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


ANALYSISD = os.path.join(find_cyb3rhq_path(), 'queue', 'sockets', 'queue')
# Max size of the event that ANALYSISID can handle
MAX_EVENT_SIZE = 65535
