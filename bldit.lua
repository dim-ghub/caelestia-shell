bldit_version = "0.1.3"
package_version = "2.0.2"
global_dependencies = {}
dependencies = {}

local legacy_libs = {
    "/usr/lib/qt6/qml/Caelestia/Components/libcaelestia-components.so",
    "/usr/lib/qt6/qml/Caelestia/Config/libcaelestia-config.so",
    "/usr/lib/qt6/qml/Caelestia/Internal/libcaelestia-internal.so",
    "/usr/lib/qt6/qml/Caelestia/Models/libcaelestia-models.so",
    "/usr/lib/qt6/qml/Caelestia/Services/libcaelestia-services.so",
    "/usr/lib/qt6/qml/Caelestia/Blobs/libcaelestia-blobs.so",
    "/usr/lib/qt6/qml/Caelestia/Images/libcaelestia-images.so",
    "/usr/lib/qt6/qml/Caelestia/libcaelestia.so"
}

local paths_to_remove = {
    "/usr/lib/qt6/qml/Caelestia",
    "/usr/lib/qt6/qml/M3Shapes",
    "/usr/lib/caelestia",
    "/etc/xdg/quickshell/caelestia"
}

local function install_arch_deps(quiet)
    local q_flag = quiet and " >/dev/null 2>&1" or ""
    if os.execute("command -v pacman >/dev/null 2>&1") == 0 then
        local deps = "ddcutil brightnessctl networkmanager lm_sensors fish aubio pipewire qt6-declarative qt6-base swappy libqalculate cmake ninja"
        local aur_deps = "quickshell-git app2unit libcava"
        
        if os.execute("command -v yay >/dev/null 2>&1") == 0 then
            os.execute("yay -S --needed --noconfirm " .. deps .. " " .. aur_deps .. q_flag)
        elseif os.execute("command -v paru >/dev/null 2>&1") == 0 then
            os.execute("paru -S --needed --noconfirm " .. deps .. " " .. aur_deps .. q_flag)
        else
            os.execute("sudo pacman -S --needed --noconfirm " .. deps .. q_flag)
            if not quiet then
                print("Please install the following AUR packages manually: " .. aur_deps)
            end
        end
    end
    return 0
end

targets = {
    default = {
        pre_build = function() return install_arch_deps(false) end,
        build = function() 
            os.execute("rm -rf build")
            os.execute("cmake -B build -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON")
            os.execute("cmake --build build -j$(nproc)")
            return 0
        end,
        install = function() 
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib)
            end
            os.execute("sudo cmake --install build")
            return 0
        end,
        uninstall = function()
            for _, p in ipairs(paths_to_remove) do
                os.execute("sudo rm -rf " .. p)
            end
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib)
            end
            os.execute("rm -rf build")
            return 0
        end,
    },
    quiet = {
        pre_build = function() return install_arch_deps(true) end,
        build = function() 
            os.execute("rm -rf build >/dev/null 2>&1")
            os.execute("cmake -B build -DCMAKE_INSTALL_PREFIX=/ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXPORT_COMPILE_COMMANDS=ON >/dev/null 2>&1")
            os.execute("cmake --build build -j$(nproc) >/dev/null 2>&1")
            return 0
        end,
        install = function() 
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib .. " >/dev/null 2>&1")
            end
            os.execute("sudo cmake --install build >/dev/null 2>&1")
            return 0
        end,
        uninstall = function()
            for _, p in ipairs(paths_to_remove) do
                os.execute("sudo rm -rf " .. p .. " >/dev/null 2>&1")
            end
            for _, lib in ipairs(legacy_libs) do
                os.execute("sudo rm -f " .. lib .. " >/dev/null 2>&1")
            end
            os.execute("rm -rf build >/dev/null 2>&1")
            return 0
        end,
    }
}
