/*
 * Cyb3rhq Syscheck
 * Copyright (C) 2015, Cyb3rhq Inc.
 * October 5, 2021.
 *
 * This program is free software; you can redistribute it
 * and/or modify it under the terms of the GNU General Public
 * License (version 2) as published by the FSF - Free Software
 * Foundation.
 */

#ifndef _FILEITEM_TEST_H
#define _FILEITEM_TEST_H
#include "gtest/gtest.h"
#include "gmock/gmock.h"

class FileItemTest : public testing::Test {
    protected:
        FileItemTest() = default;
        virtual ~FileItemTest() = default;

        void SetUp() override;
        void TearDown() override;
        fim_entry * fimEntryTest;
        nlohmann::json json;
};

#endif //_FILEITEM_TEST_H
