#!/usr/bin/env bash

# Caelestia Shell Fix & Global Installer Script
# This script configures, builds, installs, and resolves dynamic library conflicts
# introduced by old version leftovers.
#
# Usage: fix-install.sh [version]
#   version    Optional version string (e.g., "1.0.0"). Defaults to "1.0.0"
#              if not provided.

set -euo pipefail

# Harmonious HSL colors for elegant premium styling output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

VERSION="${1:-1.0.0}"

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}      Caelestia Shell Modernizer & Installer       ${NC}"
echo -e "${BLUE}===================================================${NC}"

# 1. Verify working directory
if [ ! -f "CMakeLists.txt" ] || [ ! -d "plugin/src/Caelestia" ]; then
    echo -e "${RED}Error: This script must be run from the root of the caelestia repository directory!${NC}"
    exit 1
fi

# 2. Clean up the build directory for a clean state
echo -e "${BLUE}[1/4] Cleaning up old build files...${NC}"
rm -rf build

# 3. Configure the project with proper root prefix
echo -e "${BLUE}[2/4] Configuring CMake with system prefix (/)...${NC}"

CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_INSTALL_PREFIX=/
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

if [ -n "${VERSION}" ]; then
    CMAKE_ARGS+=(-DVERSION="${VERSION}")
    echo -e "${YELLOW}Building version: ${VERSION}${NC}"
fi

cmake -B build "${CMAKE_ARGS[@]}"

# 4. Build the project
echo -e "${BLUE}[3/4] Compiling QML and C++ plugins...${NC}"
cmake --build build

# 5. Clean up hijacked legacy dynamic libraries from /usr/lib
echo -e "${BLUE}[4/4] Cleaning legacy libs and installing system-wide...${NC}"
# In old versions, backing .so libraries were installed directly to component dirs,
# which hijacks the loading of the newly compiled libraries located under Caelestia/lib.
legacy_libs=(
    "/usr/lib/qt6/qml/Caelestia/Components/libcaelestia-components.so"
    "/usr/lib/qt6/qml/Caelestia/Config/libcaelestia-config.so"
    "/usr/lib/qt6/qml/Caelestia/Internal/libcaelestia-internal.so"
    "/usr/lib/qt6/qml/Caelestia/Models/libcaelestia-models.so"
    "/usr/lib/qt6/qml/Caelestia/Services/libcaelestia-services.so"
    "/usr/lib/qt6/qml/Caelestia/Blobs/libcaelestia-blobs.so"
    "/usr/lib/qt6/qml/Caelestia/Images/libcaelestia-images.so"
    "/usr/lib/qt6/qml/Caelestia/libcaelestia.so"
)

for lib in "${legacy_libs[@]}"; do
    if [ -f "$lib" ]; then
        echo -e "${YELLOW}Removing leftover library: $lib${NC}"
        sudo rm -f "$lib"
    fi
done

sudo cmake --install build

echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}       Installation & Fix Completed Successfully!   ${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "You can now start the shell using:"
echo -e "  ${YELLOW}caelestia shell -d${NC}"
echo -e "Or kill any running shell using:"
echo -e "  ${YELLOW}caelestia shell -k${NC}"
echo -e "${GREEN}===================================================${NC}"
