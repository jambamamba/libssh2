# Copyright (C) Alexander Lamaison <alexander.lamaison@gmail.com>
# Copyright (C) Viktor Szakats
#
# Redistribution and use in source and binary forms,
# with or without modification, are permitted provided
# that the following conditions are met:
#
#   Redistributions of source code must retain the above
#   copyright notice, this list of conditions and the
#   following disclaimer.
#
#   Redistributions in binary form must reproduce the above
#   copyright notice, this list of conditions and the following
#   disclaimer in the documentation and/or other materials
#   provided with the distribution.
#
#   Neither the name of the copyright holder nor the names
#   of any other contributors may be used to endorse or
#   promote products derived from this software without
#   specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
#
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.7...3.16 FATAL_ERROR)
message(STATUS "Using CMake version ${CMAKE_VERSION}")

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

include(CheckFunctionExists)
include(CheckSymbolExists)
include(CheckIncludeFiles)
include(CMakePushCheckState)
include(FeatureSummary)

include(CheckFunctionExistsMayNeedLibrary)
include(CheckNonblockingSocketSupport)

project(libssh2 C)

# Dump all target properties
function(libssh2_dumptargetprops _target)
  if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.19 AND TARGET "${_target}")
    execute_process(COMMAND "${CMAKE_COMMAND}" "--help-property-list" OUTPUT_VARIABLE _cmake_property_list)
    string(REPLACE "\n" ";" _cmake_property_list "${_cmake_property_list}")
    list(REMOVE_DUPLICATES _cmake_property_list)
    list(REMOVE_ITEM _cmake_property_list "")
    list(APPEND _cmake_property_list "INTERFACE_LIBSSH2_PC_MODULES")
    foreach(_prop IN LISTS _cmake_property_list)
      if(_prop MATCHES "<CONFIG>")
        foreach(_config IN ITEMS "DEBUG" "RELEASE" "MINSIZEREL" "RELWITHDEBINFO")
          string(REPLACE "<CONFIG>" "${_config}" _propconfig "${_prop}")
          get_property(_is_set TARGET "${_target}" PROPERTY "${_propconfig}" SET)
          if(_is_set)
            get_target_property(_val "${_target}" "${_propconfig}")
            message("${_target}.${_propconfig} = '${_val}'")
          endif()
        endforeach()
      else()
        get_property(_is_set TARGET "${_target}" PROPERTY "${_prop}" SET)
        if(_is_set)
          get_target_property(_val "${_target}" "${_prop}")
          message("${_target}.${_prop} = '${_val}'")
        endif()
      endif()
    endforeach()
  endif()
endfunction()

# Dump all defined variables with their values
function(libssh2_dumpvars)
  message("::group::CMake Variable Dump")
  get_cmake_property(_vars VARIABLES)
  foreach(_var IN ITEMS ${_vars})
    message("${_var} = '${${_var}}'")
  endforeach()
  message("::endgroup::")
endfunction()

# CMake does not recognize some targets accurately. Touch up configuration manually as a workaround.
if(WINDOWS_STORE AND MINGW)  # mingw UWP build
  # CMake (as of v3.31.2) gets confused and applies the MSVC rc.exe command-line
  # template to windres. Reset it to the windres template via 'Modules/Platform/Windows-windres.cmake':
  set(CMAKE_RC_COMPILE_OBJECT "<CMAKE_RC_COMPILER> -O coff <DEFINES> <INCLUDES> <FLAGS> <SOURCE> <OBJECT>")
endif()

set(_target_flags "")
if(APPLE)
  string(APPEND _target_flags " APPLE")
endif()
if(UNIX)
  string(APPEND _target_flags " UNIX")
endif()
if(BSD)
  string(APPEND _target_flags " BSD")
endif()
if(ANDROID)
  string(APPEND _target_flags " ANDROID-${ANDROID_PLATFORM_LEVEL}")
endif()
if(WIN32)
  string(APPEND _target_flags " WIN32")
endif()
if(WINDOWS_STORE)
  string(APPEND _target_flags " UWP")
endif()
if(CYGWIN)
  string(APPEND _target_flags " CYGWIN")
endif()
if(MSYS)
  string(APPEND _target_flags " MSYS")
endif()
if(DOS)
  string(APPEND _target_flags " DOS")
endif()
if(AMIGA)
  string(APPEND _target_flags " AMIGA")
endif()
if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
  string(APPEND _target_flags " GCC")
endif()
if(MINGW)
  string(APPEND _target_flags " MINGW")
endif()
if(MSVC)
  string(APPEND _target_flags " MSVC-${MSVC_VERSION}")
endif()
if(VCPKG_TOOLCHAIN)
  string(APPEND _target_flags " VCPKG")
endif()
if(CMAKE_CROSSCOMPILING)
  string(APPEND _target_flags " CROSS")
endif()
message(STATUS "CMake platform flags:${_target_flags}")

if(NOT DEFINED CMAKE_UNITY_BUILD_BATCH_SIZE)
  set(CMAKE_UNITY_BUILD_BATCH_SIZE 0)
endif()

option(BUILD_STATIC_LIBS "Build static libraries" ON)
add_feature_info("Static library" BUILD_STATIC_LIBS "creating libssh2 static library")

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
add_feature_info("Shared library" BUILD_SHARED_LIBS "creating libssh2 shared library (.so/.dll)")

# Parse version

file(READ "${PROJECT_SOURCE_DIR}/include/libssh2.h" _header_contents)
string(REGEX REPLACE ".*#define LIBSSH2_VERSION[ \t]+\"([^\"]+)\".*" "\\1" LIBSSH2_VERSION "${_header_contents}")
string(REGEX REPLACE ".*#define LIBSSH2_VERSION_MAJOR[ \t]+([0-9]+).*" "\\1" LIBSSH2_VERSION_MAJOR "${_header_contents}")
string(REGEX REPLACE ".*#define LIBSSH2_VERSION_MINOR[ \t]+([0-9]+).*" "\\1" LIBSSH2_VERSION_MINOR "${_header_contents}")
string(REGEX REPLACE ".*#define LIBSSH2_VERSION_PATCH[ \t]+([0-9]+).*" "\\1" LIBSSH2_VERSION_PATCH "${_header_contents}")
unset(_header_contents)

if(NOT LIBSSH2_VERSION OR
   NOT LIBSSH2_VERSION_MAJOR MATCHES "^[0-9]+$" OR
   NOT LIBSSH2_VERSION_MINOR MATCHES "^[0-9]+$" OR
   NOT LIBSSH2_VERSION_PATCH MATCHES "^[0-9]+$")
  message(FATAL_ERROR "Unable to parse version from ${PROJECT_SOURCE_DIR}/include/libssh2.h")
endif()

include(GNUInstallDirs)
install(
  FILES
    COPYING NEWS README RELEASE-NOTES
    docs/AUTHORS docs/BINDINGS.md docs/HACKING.md
  DESTINATION ${CMAKE_INSTALL_DOCDIR})

include(PickyWarnings)

set(LIBSSH2_LIBS_SOCKET "")
set(LIBSSH2_LIBS "")

# Add socket libraries
if(WIN32)
  list(APPEND LIBSSH2_LIBS_SOCKET "ws2_32")
else()
  libssh2_check_function_exists_may_need_library("socket" HAVE_SOCKET "socket")
  if(NEED_LIB_SOCKET)
    list(APPEND LIBSSH2_LIBS_SOCKET "socket")
  endif()
  libssh2_check_function_exists_may_need_library("inet_addr" HAVE_INET_ADDR "nsl")
  if(NEED_LIB_NSL)
    list(APPEND LIBSSH2_LIBS_SOCKET "nsl")
  endif()
endif()

if(BUILD_TESTING AND NOT BUILD_STATIC_LIBS)
  # Build static for tests only, but do not install it.
  set(BUILD_STATIC_FOR_TESTS ON)
endif()

option(BUILD_EXAMPLES "Build libssh2 examples" ON)
option(BUILD_TESTING "Build libssh2 test suite" ON)
option(BUILD_OSSFUZZ "Build libssh2 OSS-Fuzz" OFF)

if((NOT BUILD_STATIC_LIBS AND NOT BUILD_SHARED_LIBS) OR BUILD_OSSFUZZ)
  set(BUILD_STATIC_LIBS ON)
endif()

set(LIB_NAME "libssh2")
set(LIB_STATIC "${LIB_NAME}_static")
set(LIB_SHARED "${LIB_NAME}_shared")

# lib flavour selected for example and test programs.
if(BUILD_SHARED_LIBS)
  set(LIB_SELECTED ${LIB_SHARED})
else()
  set(LIB_SELECTED ${LIB_STATIC})
endif()

# Override to force-disable or force-enable the use of pkg-config.
if((UNIX AND NOT ANDROID AND (NOT APPLE OR CMAKE_SYSTEM_NAME MATCHES "Darwin")) OR
   VCPKG_TOOLCHAIN OR
   (MINGW AND NOT CMAKE_CROSSCOMPILING))
  set(_libssh2_use_pkgconfig_default ON)
else()
  set(_libssh2_use_pkgconfig_default OFF)
endif()
option(LIBSSH2_USE_PKGCONFIG "Enable pkg-config to detect dependencies" ${_libssh2_use_pkgconfig_default})

# Symbol hiding

option(HIDE_SYMBOLS "Hide all libssh2 symbols that are not officially external" ON)
mark_as_advanced(HIDE_SYMBOLS)
if(HIDE_SYMBOLS)
  set(LIB_SHARED_DEFINITIONS "LIBSSH2_EXPORTS")
  if(WIN32)
  elseif((CMAKE_C_COMPILER_ID MATCHES "Clang") OR
         (CMAKE_C_COMPILER_ID STREQUAL "GNU" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 4.0) OR
         (CMAKE_C_COMPILER_ID MATCHES "Intel" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 9.1))
    set(LIB_SHARED_C_FLAGS "-fvisibility=hidden")
    set(LIBSSH2_API "__attribute__((__visibility__(\"default\")))")
  elseif(CMAKE_C_COMPILER_ID MATCHES "SunPro" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 8.0)
    set(LIB_SHARED_C_FLAGS "-xldscope=hidden")
    set(LIBSSH2_API "__global")
  endif()
endif()

# Options

# Enable debugging logging by default if the user configured a debug build
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(DEBUG_LOGGING_DEFAULT ON)
else()
  set(DEBUG_LOGGING_DEFAULT OFF)
endif()
option(ENABLE_DEBUG_LOGGING "Log execution with debug trace" ${DEBUG_LOGGING_DEFAULT})
add_feature_info("Logging" ENABLE_DEBUG_LOGGING "Logging of execution with debug trace")
if(ENABLE_DEBUG_LOGGING)
  # Must be visible to the library and tests using internals
  set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS "LIBSSH2DEBUG")
endif()

option(LIBSSH2_NO_DEPRECATED "Build without deprecated APIs" OFF)
add_feature_info("Without deprecated APIs" LIBSSH2_NO_DEPRECATED "")
if(LIBSSH2_NO_DEPRECATED)
  set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS "LIBSSH2_NO_DEPRECATED")
endif()

option(LIBSSH2_CLANG_TIDY "Run the build through clang-tidy" OFF)
if(LIBSSH2_CLANG_TIDY)
  set(CMAKE_UNITY_BUILD OFF)
  set(_tidy_checks "")
  list(APPEND _tidy_checks "-clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling")
  string(REPLACE ";" "," _tidy_checks "${_tidy_checks}")
  find_program(CLANG_TIDY NAMES "clang-tidy" REQUIRED)
  set(CMAKE_C_CLANG_TIDY "${CLANG_TIDY}" "-checks=${_tidy_checks}" "-quiet")
  unset(_tidy_checks)
  if(ENABLE_WERROR)
    list(APPEND CMAKE_C_CLANG_TIDY "--warnings-as-errors=*")
  endif()
  if(LIBSSH2_CLANG_TIDYFLAGS)
    list(APPEND CMAKE_C_CLANG_TIDY ${LIBSSH2_CLANG_TIDYFLAGS})
  endif()
endif()

# Auto-detection

# Prefill values with known detection results
# Keep this synced with src/libssh2_setup.h
if(WIN32)
  if(MINGW)
    set(HAVE_SNPRINTF 1)
    set(HAVE_UNISTD_H 1)
    set(HAVE_INTTYPES_H 1)
    set(HAVE_SYS_TIME_H 1)
    set(HAVE_GETTIMEOFDAY 1)
    set(HAVE_STRTOLL 1)
  elseif(MSVC)
    set(HAVE_GETTIMEOFDAY 0)
    set(HAVE_UNISTD_H 0)
    set(HAVE_SYS_TIME_H 0)
    if(MSVC_VERSION GREATER_EQUAL 1800)
      set(HAVE_INTTYPES_H 1)
      set(HAVE_STRTOLL 1)
    else()
      set(HAVE_INTTYPES_H 0)
      set(HAVE_STRTOLL 0)
      set(HAVE_STRTOI64 1)
    endif()
    if(MSVC_VERSION GREATER_EQUAL 1900)
      set(HAVE_SNPRINTF 1)
    else()
      set(HAVE_SNPRINTF 0)
    endif()
  endif()
  set(HAVE_POLL 0)
  set(HAVE_SELECT 1)
endif()

## Platform checks
check_include_files("inttypes.h" HAVE_INTTYPES_H)
check_include_files("unistd.h" HAVE_UNISTD_H)
check_include_files("sys/time.h" HAVE_SYS_TIME_H)  # Available on all non-Windows and mingw-w64
if(NOT WIN32)
  check_include_files("sys/select.h" HAVE_SYS_SELECT_H)
  check_include_files("sys/uio.h" HAVE_SYS_UIO_H)
  check_include_files("sys/socket.h" HAVE_SYS_SOCKET_H)
  check_include_files("sys/ioctl.h" HAVE_SYS_IOCTL_H)
  check_include_files("sys/un.h" HAVE_SYS_UN_H)
  check_include_files("arpa/inet.h" HAVE_ARPA_INET_H)  # example and tests
  check_include_files("netinet/in.h" HAVE_NETINET_IN_H)  # example and tests
endif()

# CMake uses C syntax in check_symbol_exists() that generates a warning with
# MSVC. To not break detection with ENABLE_WERRROR, we disable it for the
# duration of these tests.
if(MSVC AND ENABLE_WERROR)
  cmake_push_check_state()
  string(APPEND CMAKE_REQUIRED_FLAGS " -WX-")
endif()

if(HAVE_SYS_TIME_H)
  check_symbol_exists("gettimeofday" "sys/time.h" HAVE_GETTIMEOFDAY)
else()
  check_function_exists("gettimeofday" HAVE_GETTIMEOFDAY)
endif()
check_symbol_exists("strtoll" "stdlib.h" HAVE_STRTOLL)
if(NOT HAVE_STRTOLL)
  # Try _strtoi64() if strtoll() is not available
  check_symbol_exists("_strtoi64" "stdlib.h" HAVE_STRTOI64)
endif()
check_symbol_exists("snprintf" "stdio.h" HAVE_SNPRINTF)
if(NOT WIN32)
  check_symbol_exists("explicit_bzero" "string.h" HAVE_EXPLICIT_BZERO)
  check_symbol_exists("explicit_memset" "string.h" HAVE_EXPLICIT_MEMSET)
  check_symbol_exists("memset_s" "string.h" HAVE_MEMSET_S)
endif()

if(MSVC AND ENABLE_WERROR)
  cmake_pop_check_state()
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin" OR
   CMAKE_SYSTEM_NAME STREQUAL "Interix")
  # poll() does not work on these platforms
  #
  # Interix: "does provide poll(), but the implementing developer must
  # have been in a bad mood, because poll() only works on the /proc
  # filesystem here"
  #
  # macOS poll() has funny behaviors, like:
  # not being able to do poll on no filedescriptors (10.3?)
  # not being able to poll on some files (like anything in /dev)
  # not having reliable timeout support
  # inconsistent return of POLLHUP where other implementations give POLLIN
  message(STATUS "poll use is disabled on this platform")
else()
  check_function_exists("poll" HAVE_POLL)
endif()
check_function_exists("select" HAVE_SELECT)

# Non-blocking socket support tests. Use a separate, yet unset variable
# for the socket libraries to not link against the other configured
# dependencies which might not have been built yet.
if(NOT WIN32)
  cmake_push_check_state()
  list(APPEND CMAKE_REQUIRED_LIBRARIES ${LIBSSH2_LIBS_SOCKET})
  libssh2_check_nonblocking_socket_support()
  cmake_pop_check_state()
endif()

# Config file

set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS "HAVE_CONFIG_H")

configure_file("src/libssh2_config_cmake.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/src/libssh2_config.h")

## Cryptography backend choice

set(CRYPTO_BACKEND "" CACHE
  STRING "The backend to use for cryptography: OpenSSL, wolfSSL, Libgcrypt, WinCNG, mbedTLS, or empty to try any available")

# If the crypto backend was given, rather than searching for the first
# we are able to find, the find_package commands must abort configuration
# and report to the user.
if(CRYPTO_BACKEND)
  set(_specific_crypto_requirement "REQUIRED")
endif()

if(CRYPTO_BACKEND STREQUAL "OpenSSL" OR NOT CRYPTO_BACKEND)
  find_package(OpenSSL ${_specific_crypto_requirement} COMPONENTS Crypto)
  if(OPENSSL_FOUND)
    set(CRYPTO_BACKEND "OpenSSL")
    set(CRYPTO_BACKEND_DEFINE "LIBSSH2_OPENSSL")
    list(APPEND LIBSSH2_LIBS OpenSSL::Crypto)
    set_target_properties(OpenSSL::Crypto PROPERTIES INTERFACE_LIBSSH2_PC_MODULES "libcrypto")

    if(WIN32)
      # Statically linking to OpenSSL requires crypt32 for some Windows APIs.
      # This should really be handled by FindOpenSSL.cmake.
      list(APPEND LIBSSH2_LIBS "crypt32" "bcrypt")

      #set(CMAKE_FIND_DEBUG_MODE ON)

      find_file(DLL_LIBCRYPTO
        NAMES "crypto.dll"
          "libcrypto-1_1.dll" "libcrypto-1_1-x64.dll"
          "libcrypto-3.dll" "libcrypto-3-x64.dll"
        HINTS ${_OPENSSL_ROOT_HINTS} PATHS ${_OPENSSL_ROOT_PATHS}
        PATH_SUFFIXES "bin" NO_DEFAULT_PATH)
      if(DLL_LIBCRYPTO)
        list(APPEND __runtime_dependencies ${DLL_LIBCRYPTO})
        message(STATUS "Found libcrypto DLL: ${DLL_LIBCRYPTO}")
      else()
        message(WARNING "Unable to find OpenSSL libcrypto DLL, executables may not run")
      endif()

      #set(CMAKE_FIND_DEBUG_MODE OFF)
    endif()

    find_package(ZLIB)
    if(ZLIB_FOUND)
      list(APPEND LIBSSH2_LIBS ZLIB::ZLIB)
    endif()
  endif()
endif()

if(CRYPTO_BACKEND STREQUAL "wolfSSL" OR NOT CRYPTO_BACKEND)
  find_package(WolfSSL ${_specific_crypto_requirement})
  if(WOLFSSL_FOUND)
    set(CRYPTO_BACKEND "wolfSSL")
    set(CRYPTO_BACKEND_DEFINE "LIBSSH2_WOLFSSL")
    list(APPEND LIBSSH2_LIBS libssh2::wolfssl)

    find_package(ZLIB)
    if(ZLIB_FOUND)
      list(APPEND LIBSSH2_LIBS ZLIB::ZLIB)  # Public wolfSSL headers require zlib headers
    endif()
  endif()
endif()

if(CRYPTO_BACKEND STREQUAL "Libgcrypt" OR NOT CRYPTO_BACKEND)
  find_package(Libgcrypt ${_specific_crypto_requirement})
  if(LIBGCRYPT_FOUND)
    set(CRYPTO_BACKEND "Libgcrypt")
    set(CRYPTO_BACKEND_DEFINE "LIBSSH2_LIBGCRYPT")
    list(APPEND LIBSSH2_LIBS libssh2::libgcrypt)
  endif()
endif()

if(CRYPTO_BACKEND STREQUAL "mbedTLS" OR NOT CRYPTO_BACKEND)
  find_package(MbedTLS ${_specific_crypto_requirement})
  if(MBEDTLS_FOUND)
    set(CRYPTO_BACKEND "mbedTLS")
    set(CRYPTO_BACKEND_DEFINE "LIBSSH2_MBEDTLS")
    list(APPEND LIBSSH2_LIBS libssh2::mbedcrypto)
  endif()
endif()

# Detect platform-specific crypto-backends last:

if(CRYPTO_BACKEND STREQUAL "WinCNG" OR NOT CRYPTO_BACKEND)
  if(WIN32)
    set(CRYPTO_BACKEND "WinCNG")
    set(CRYPTO_BACKEND_DEFINE "LIBSSH2_WINCNG")
    list(APPEND LIBSSH2_LIBS "crypt32" "bcrypt")

    option(ENABLE_ECDSA_WINCNG "Enable WinCNG ECDSA support (requires Windows 10 or later)" OFF)
    add_feature_info("WinCNG" ENABLE_ECDSA_WINCNG "WinCNG ECDSA support")
    if(ENABLE_ECDSA_WINCNG)
      set_property(DIRECTORY APPEND PROPERTY COMPILE_DEFINITIONS "LIBSSH2_ECDSA_WINCNG")
      if(MSVC)
        string(APPEND CMAKE_SHARED_LINKER_FLAGS " -SUBSYSTEM:WINDOWS,10")
      elseif(MINGW)
        string(APPEND CMAKE_SHARED_LINKER_FLAGS " -Wl,--subsystem,windows:10")
      endif()
    endif()
  elseif(_specific_crypto_requirement STREQUAL "REQUIRED")
    message(FATAL_ERROR "WinCNG not available")
  endif()
endif()

# Global functions

# Convert GNU Make assignments into CMake ones.
function(libssh2_transform_makefile_inc _input_file _output_file)
  file(READ ${_input_file} _makefile_inc_cmake)

  string(REGEX REPLACE "\\\\\n" "" _makefile_inc_cmake ${_makefile_inc_cmake})
  string(REGEX REPLACE "([A-Za-z_]+) *= *([^\n]*)" "set(\\1 \\2)" _makefile_inc_cmake ${_makefile_inc_cmake})

  file(WRITE ${_output_file} ${_makefile_inc_cmake})
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${_input_file}")
endfunction()

#

add_subdirectory(src)

if(BUILD_EXAMPLES)
  add_subdirectory(example)
endif()

if(BUILD_TESTING)
  enable_testing()
  add_subdirectory(tests)
endif()

option(LINT "Check style while building" OFF)
if(LINT)
  add_custom_target(lint ALL "./ci/checksrc.sh" WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})
  if(BUILD_STATIC_LIBS)
    add_dependencies(${LIB_STATIC} lint)
  else()
    add_dependencies(${LIB_SHARED} lint)
  endif()
endif()

add_subdirectory(docs)

feature_summary(WHAT ALL)

set(CPACK_PACKAGE_VERSION_MAJOR ${LIBSSH2_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${LIBSSH2_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${LIBSSH2_VERSION_PATCH})
set(CPACK_PACKAGE_VERSION ${LIBSSH2_VERSION})
include(CPack)

