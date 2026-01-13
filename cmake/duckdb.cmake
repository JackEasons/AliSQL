# Copyright (c) 2025, Alibaba and/or its affiliates. All Rights Reserved.
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License, version 2.0, as published by the
# Free Software Foundation.
# 
# This program is also distributed with certain software (including but not
# limited to OpenSSL) that is licensed under separate terms, as designated in a
# particular file or component or in included license documentation. The authors
# of MySQL hereby grant you an additional permission to link the program and
# your derivative works with the separately licensed software that they have
# included with MySQL.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License, version 2.0,
# for more details.
# 
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA

INCLUDE(ExternalProject)
INCLUDE(FetchContent)

SET(DUCKDB_NAME "duckdb")
SET(DUCKDB_DIR "extra/${DUCKDB_NAME}")
SET(DUCKDB_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${DUCKDB_DIR}")

IF(CMAKE_BUILD_TYPE STREQUAL "Debug")
  SET(DUCKDB_BUILD_TYPE "bundle-library-debug")
  SET(DUCKDB_BUILD_DIR "debug")
ELSE()
  SET(DUCKDB_BUILD_TYPE "bundle-library")
  SET(DUCKDB_BUILD_DIR "release")
ENDIF()

MACRO (MYSQL_USE_BUNDLED_DUCKDB)
  MESSAGE(STATUS "=== Setting up DuckDB from submodule ===")

  FIND_PACKAGE(Git QUIET)
  IF(NOT GIT_FOUND)
    MESSAGE(FATAL_ERROR "Git not found. Please install git to build with DuckDB submodule.")
  ENDIF()

  IF(EXISTS "${CMAKE_SOURCE_DIR}/.git" OR EXISTS "${CMAKE_SOURCE_DIR}/.git/")
    MESSAGE(STATUS "Initializing DuckDB submodule...")

    execute_process(
      COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive
      WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
      RESULT_VARIABLE GIT_SUBMOD_RESULT
      OUTPUT_QUIET
    )

    if(NOT GIT_SUBMOD_RESULT EQUAL 0)
      message(WARNING "Failed to init/update DuckDB submodule. Run manually: git submodule update --init --recursive")
    endif()
  ENDIF()

  IF(EXISTS ${DUCKDB_SOURCE_DIR}/.git)
    execute_process(
      COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
      WORKING_DIRECTORY ${DUCKDB_SOURCE_DIR}
      OUTPUT_VARIABLE CURRENT_BRANCH
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(NOT CURRENT_BRANCH STREQUAL "duckdb_for_submodule")
      message(WARNING "DuckDB submodule is on branch '${CURRENT_BRANCH}', expected 'duckdb_for_submodule'. Forcing checkout...")
      execute_process(
        COMMAND ${GIT_EXECUTABLE} checkout duckdb_for_submodule
        WORKING_DIRECTORY ${DUCKDB_SOURCE_DIR}
        RESULT_VARIABLE CHECKOUT_RESULT
      )
      if(NOT CHECKOUT_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to switch DuckDB submodule to branch 'duckdb_for_submodule'")
      endif()
    else()
      message(STATUS "DuckDB submodule on correct branch: ${CURRENT_BRANCH}")
    endif()
  ELSE()
    message(FATAL_ERROR "DuckDB submodule not initialized. Run: git submodule update --init --recursive")
  ENDIF()

  SET(BINARY_DIR "${CMAKE_BINARY_DIR}/${CMAKE_CFG_INTDIR}/${DUCKDB_DIR}/build")
  SET(DUCKDB_INCLUDE_DIR ${DUCKDB_SOURCE_DIR}/src/include)

  ExternalProject_Add(duckdb_proj
    PREFIX ${DUCKDB_DIR}
    SOURCE_DIR ${DUCKDB_SOURCE_DIR}
    BINARY_DIR ${BINARY_DIR}
    STAMP_DIR "${BINARY_DIR}/${DUCKDB_BUILD_DIR}/stamp"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND make -C ${DUCKDB_SOURCE_DIR} ${DUCKDB_BUILD_TYPE} > /dev/null 2>&1
    INSTALL_COMMAND ""
    BUILD_ALWAYS OFF
  )

  SET(MY_DUCKDB_LIB "${BINARY_DIR}/${DUCKDB_BUILD_DIR}/libduckdb_bundle.a")
  IF(NOT EXISTS ${MY_DUCKDB_LIB})
    MESSAGE(STATUS "DuckDB library will be built at: ${MY_DUCKDB_LIB}")
  ENDIF()

  ADD_LIBRARY(libduckdb STATIC IMPORTED GLOBAL)
  SET_TARGET_PROPERTIES(libduckdb PROPERTIES IMPORTED_LOCATION "${MY_DUCKDB_LIB}")
  ADD_DEPENDENCIES(libduckdb duckdb_proj)

  INCLUDE_DIRECTORIES(BEFORE SYSTEM ${DUCKDB_INCLUDE_DIR})

  MESSAGE(STATUS "DuckDB setup complete: using branch 'duckdb_for_submodule'")
  MESSAGE(STATUS "Include: ${DUCKDB_INCLUDE_DIR}")
  MESSAGE(STATUS "Library: ${MY_DUCKDB_LIB}")
ENDMACRO()

MACRO (MYSQL_CHECK_DUCKDB)
  MYSQL_USE_BUNDLED_DUCKDB()
  SET(DUCKDB_LIBRARY libduckdb)
ENDMACRO()
