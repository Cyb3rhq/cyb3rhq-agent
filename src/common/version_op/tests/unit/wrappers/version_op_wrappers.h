/* Copyright (C) 2015, Cyb3rhq Inc.
 * All rights reserved.
 *
 * This program is free software; you can redistribute it
 * and/or modify it under the terms of the GNU General Public
 * License (version 2) as published by the FSF - Free Software
 * Foundation
 */


#ifndef VERSION_OP_WRAPPERS_H
#define VERSION_OP_WRAPPERS_H

#include <stdbool.h>

int __wrap_compare_cyb3rhq_versions(const char *version1, const char *version2, bool compare_patch);

#endif
