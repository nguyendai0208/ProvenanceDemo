#!/usr/bin/env bash

cmake ../dolphin-ios \
-G Xcode \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
-DCMAKE_TOOLCHAIN_FILE=./ios.toolchain.cmake \
-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="iPhone Developer" \
-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="XXXXXXXXXX" \
-DCMAKE_XCODE_ATTRIBUTE_PROVISIONING_PROFILE_SPECIFIER="iOS Team Provisioning Profile: *" \
-DDEPLOYMENT_TARGET="13.0" \
-DDISTRIBUTOR="Provenance EMU" \
-DCPACK_BINARY_STGZ=OFF \
-DCPACK_BINARY_TGZ=OFF \
-DENABLE_ALSA=NO \
-DENABLE_ANALYTICS=NO \
-DENABLE_AUTOUPDATE=NO \
-DENABLE_BITCODE=NO \
-DENABLE_BULLETPROOF_JIT=YES \
-DENABLE_CLI_TOOL=NO \
-DENABLE_CLI_TOOLS=NO \
-DENABLE_HEADLESS=YES \
-DENABLE_LTO=YES \
-DENABLE_METAL=YES \
-DENABLE_NOGUI=NO \
-DENABLE_PULSEAUDIO=NO \
-DENABLE_QT=NO \
-DENABLE_SDL=NO \
-DENABLE_TESTS=NO \
-DENABLE_VULKAN=ON \
-DENCODE_FRAMEDUMPS=NO \
-DFMT_EXCEPTIONS=NO \
-DIOS=YES \
-DIPHONEOS=YES \
-DMACOS_CODE_SIGNING=NO \
-DPLATFORM_DEPLOYMENT_TARGET=13 \
-DPLATFORM=OS64COMBINED \
-DSDL_FRAMEWORK=YES \
-DSDL_HIDAPI_LIBUSB_SHARED=NO \
-DSDL_HIDAPI_LIBUSB=NO \
-DSDL_HIDAPI=NO \
-DSDL_RENDER_D3D=NO \
-DTARGET_IOS=ON \
-DUSE_DISCORD_PRESENCE=NO \
-DUSE_MGBA=NO \
-DUSE_RETRO_ACHIEVEMENTS=NO \
-DUSE_UPNP=NO \
-DSKIP_POSTPROCESS_BUNDLE=ON \
-DFMT_INSTALL=NO \
-DGDBSTUB=NO \
-DHAVE_PTHREAD_CONDATTR_SETCLOCK=NO \
-DHAVE_PIPE2=NO \
-DHAVE_IOKIT_USB_IOUSBHOSTFAMILYDEFINITIONS_H=NO \
-DPNG_HARDWARE_OPTIMIZATIONS=NO

python3 xcode_absolute_path_to_relative.py

## Unused variables for reference
# -DCMAKE_OSX_ARCHITECTURES="arm64"
# -DFRAMEWORK_VULKAN_LIBS=${FRAMEWORK_VULKAN_LIBS}
# -DUSE_GSH_VULKAN=ON
# -DCMAKE_PREFIX_PATH="${VULKAN_SDK}"
# -DVulkan_INCLUDE_DIR=${Vulkan_INCLUDE_DIR}
# -DCMAKE_C_FLAGS="-DIOS -DAPPLE -D_BULLETPROOF_JIT=1 -DAPPLE=YES"
#
# //Debug library postfix.
# FMT_DEBUG_POSTFIX:STRING=d