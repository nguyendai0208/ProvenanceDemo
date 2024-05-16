# This file will be configured to contain variables for CPack. These variables
# should be set in the CMake list file of the project before CPack module is
# included. The list of available CPACK_xxx variables and their associated
# documentation may be obtained using
#  cpack --help-variable-list
#
# Some variables are common to all generators (e.g. CPACK_PACKAGE_NAME)
# and some are specific to a generator
# (e.g. CPACK_NSIS_EXTRA_INSTALL_COMMANDS). The generator specific variables
# usually begin with CPACK_<GENNAME>_xxxx.


set(CPACK_BINARY_BUNDLE "OFF")
set(CPACK_BINARY_DEB "OFF")
set(CPACK_BINARY_DRAGNDROP "OFF")
set(CPACK_BINARY_FREEBSD "OFF")
set(CPACK_BINARY_IFW "OFF")
set(CPACK_BINARY_NSIS "OFF")
set(CPACK_BINARY_PRODUCTBUILD "OFF")
set(CPACK_BINARY_RPM "OFF")
set(CPACK_BINARY_STGZ "ON")
set(CPACK_BINARY_TBZ2 "OFF")
set(CPACK_BINARY_TGZ "ON")
set(CPACK_BINARY_TXZ "OFF")
set(CPACK_BUILD_SOURCE_DIRS "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake")
set(CPACK_CMAKE_GENERATOR "Xcode")
set(CPACK_COMPONENT_UNSPECIFIED_HIDDEN "TRUE")
set(CPACK_COMPONENT_UNSPECIFIED_REQUIRED "TRUE")
set(CPACK_DEFAULT_PACKAGE_DESCRIPTION_FILE "/opt/homebrew/Cellar/cmake/3.25.1/share/cmake/Templates/CPack.GenericDescription.txt")
set(CPACK_DEFAULT_PACKAGE_DESCRIPTION_SUMMARY "dolphin-emu built using CMake")
set(CPACK_GENERATOR "STGZ;TGZ")
set(CPACK_INSTALL_CMAKE_PROJECTS "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake;dolphin-emu;ALL;/")
set(CPACK_INSTALL_PREFIX "/usr/local")
set(CPACK_MODULE_PATH "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/CMake")
set(CPACK_NSIS_DISPLAY_NAME "dolphin-emu 5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_NSIS_INSTALLER_ICON_CODE "")
set(CPACK_NSIS_INSTALLER_MUI_ICON_CODE "")
set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES")
set(CPACK_NSIS_PACKAGE_NAME "dolphin-emu 5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_NSIS_UNINSTALL_NAME "Uninstall")
set(CPACK_OBJDUMP_EXECUTABLE "/Applications/Xcode-14.2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
set(CPACK_OSX_SYSROOT "/Applications/Xcode-14.2.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.2.sdk")
set(CPACK_OUTPUT_CONFIG_FILE "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/CPackConfig.cmake")
set(CPACK_PACKAGE_DEFAULT_LOCATION "/")
set(CPACK_PACKAGE_DESCRIPTION_FILE "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Data/cpack_package_description.txt")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A GameCube and Wii emulator")
set(CPACK_PACKAGE_FILE_NAME "dolphin-emu-5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13-iOS")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "dolphin-emu 5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_PACKAGE_INSTALL_REGISTRY_KEY "dolphin-emu 5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_PACKAGE_NAME "dolphin-emu")
set(CPACK_PACKAGE_RELOCATABLE "true")
set(CPACK_PACKAGE_VENDOR "Dolphin Team")
set(CPACK_PACKAGE_VERSION "5.0.1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_PACKAGE_VERSION_MAJOR "5")
set(CPACK_PACKAGE_VERSION_MINOR "0")
set(CPACK_PACKAGE_VERSION_PATCH "1780da7bfe5488b420b9cbf265c0b70793cf0d13")
set(CPACK_RESOURCE_FILE_LICENSE "/opt/homebrew/Cellar/cmake/3.25.1/share/cmake/Templates/CPack.GenericLicense.txt")
set(CPACK_RESOURCE_FILE_README "/opt/homebrew/Cellar/cmake/3.25.1/share/cmake/Templates/CPack.GenericDescription.txt")
set(CPACK_RESOURCE_FILE_WELCOME "/opt/homebrew/Cellar/cmake/3.25.1/share/cmake/Templates/CPack.GenericWelcome.txt")
set(CPACK_RPM_PACKAGE_GROUP "System/Emulators/Other")
set(CPACK_RPM_PACKAGE_LICENSE "GPL-2.0")
set(CPACK_SET_DESTDIR "ON")
set(CPACK_SOURCE_GENERATOR "TGZ;TBZ2;ZIP")
set(CPACK_SOURCE_IGNORE_FILES "\\.#;/#;.*~;\\.swp;/\\.git;/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake")
set(CPACK_SOURCE_OUTPUT_CONFIG_FILE "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/CPackSourceConfig.cmake")
set(CPACK_SYSTEM_NAME "iOS")
set(CPACK_THREADS "1")
set(CPACK_TOPLEVEL_TAG "iOS")
set(CPACK_WIX_SIZEOF_VOID_P "8")

if(NOT CPACK_PROPERTIES_FILE)
  set(CPACK_PROPERTIES_FILE "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/CPackProperties.cmake")
endif()

if(EXISTS ${CPACK_PROPERTIES_FILE})
  include(${CPACK_PROPERTIES_FILE})
endif()
