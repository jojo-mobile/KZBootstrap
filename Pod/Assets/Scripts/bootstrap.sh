#!/bin/sh

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${DIR}" ]]; then DIR="${PWD}"; fi
. "${DIR}/iconVersioning.sh"
. "${DIR}/lines.sh"
. "${DIR}/todo.sh"
. "${DIR}/user.sh"

bundled_plist=$(find "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" -name "KZBEnvironments.plist" | tr -d '\r')
bundled_settings=$(find "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" -name "Settings.bundle" | tr -d '\r')
src_plist=$(find "${SRCROOT}" -name "KZBEnvironments.plist" | tr -d '\r')
src_settings=$(find "${SRCROOT}" -name "Settings.bundle" | tr -d '\r')

echo bundled_plist $bundled_plist
echo bundled_settings source $bundled_settings
echo src_plist $src_plist
echo src_settings $src_settings

if [[ -z "$src_settings" ]]
then
    settings="${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Settings.bundle"
    settings_root_file="${settings}/Root.plist"
    rm -r -f ${settings}

    if [ ${CONFIGURATION} != 'Release' ]; then
        mkdir ${settings}

        touch ${settings_root_file}
        echo '<?xml version="1.0" encoding="UTF-8"?>' >> ${settings_root_file}
        echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ${settings_root_file}
        echo '<plist version="1.0">' >> ${settings_root_file}
        echo '<dict>' >> ${settings_root_file}
        echo '<key>PreferenceSpecifiers</key>' >> ${settings_root_file}
        echo '<array/>' >> ${settings_root_file}
        echo '<key>StringsTable</key>' >> ${settings_root_file}
        echo '<string>Root</string>' >> ${settings_root_file}
        echo '</dict>' >> ${settings_root_file}
        echo '</plist>' >> ${settings_root_file}
        cat ${settings_root_file}
    fi
else
    echo settings exists
fi
bundled_settings=$(find "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" -name "Settings.bundle" | tr -d '\r')


if [[ -z "${KZBDefaultEnv}" ]]; then
    echo KZBDefaultEnv must be set
    exit 1
else
    env -i xcrun -sdk macosx swift "${DIR}/processEnvironments.swift" "${bundled_plist}" "${src_plist}" "${bundled_settings}" "${KZBDefaultEnv}" "${CONFIGURATION}"

fi
