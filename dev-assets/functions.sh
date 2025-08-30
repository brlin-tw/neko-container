# shellcheck shell=bash
# Common function definitions
#
# Copyright 2025 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: CC-BY-SA-4.0+

# Query the operating system distribution identifier
#
# Standard output: Result operating system distribution identifier
# Return values:
#
# * 0: OS identifier found
# * 1: Prerequisite not met
# * 2: Generic error
get_distro_identifier(){
    local operating_system_information_file=/etc/os-release

    # Out of scope
    # shellcheck source=/dev/null
    if ! source "${operating_system_information_file}"; then
        printf \
            '%s: Error: Unable to load the operating system information file.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -v ID; then
        printf \
            '%s: Error: The ID variable assignment not found from the operating system information file(%s).\n' \
            "${FUNCNAME[0]}" \
            "${operating_system_information_file}" \
            1>&2
        return 2
    fi

    printf '%s' "${ID}"
}

# Query the operating system distribution categories
#
# Standard output: Result operating system distribution categories(or empty string if not applicable)
#
# Return values:
#
# * 0: Operation successful
# * 1: Prerequisite not met
# * 2: Generic error
get_distro_categories(){
    local operating_system_information_file=/etc/os-release

    # Out of scope
    # shellcheck source=/dev/null
    if ! source "${operating_system_information_file}"; then
        printf \
            '%s: Error: Unable to load the operating system information file.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! test -v ID_LIKE; then
        # ArchLinux does not have the ID_LIKE variable in the /etc/os-release file
        ID_LIKE=
    fi

    printf '%s' "${ID_LIKE}"
}

# Check whether the specified command exists in the command search PATHs
#
# Parameters:
#
# * command: The command to check for existence
#
# Return values:
#
# * 0: Command exists
# * 1: Command does not exist
check_command_existence(){
    local command="${1}"

    if ! command -v "${command}" >/dev/null; then
        printf \
            'Error: The "%s" command is required but not found in your command search PATHs.\n' \
            "${command}" \
            1>&2
        return 1
    fi

    return 0
}

# Determine the required commands for the current distribution
#
# Parameters:
#
# * distro_id: The OS distribution identifier
# * distro_categories: The OS distribution categories
#
# Standard output: Space-separated list of required commands
# Return values:
#
# * 0: Commands determined successfully
# * 1: Unsupported distribution
# * 2: Generic error
determine_required_commands(){
    local distro_id="${1}"
    local distro_categories="${2}"

    local -a required_commands=()

    case "${distro_categories}" in
        *debian*)
            required_commands+=(
                dpkg
                apt-get
            )
        ;;
        *rhel*)
            required_commands+=(
                rpm
            )
            if ! check_command_existence dnf; then
                required_commands+=(
                    yum
                )
            fi
        ;;
        '')
            case "${distro_id}" in
                arch)
                    required_commands+=(
                        pacman
                    )
                ;;
                *)
                    printf \
                        '%s: Error: Unsupported OS distribution: %s.\n' \
                        "${FUNCNAME[0]}" \
                        "${distro_id}" \
                        1>&2
                    return 2
                ;;
            esac
        ;;
        *)
            printf \
                '%s: Error: Unsupported OS distribution categories: %s.\n' \
                "${FUNCNAME[0]}" \
                "${distro_categories}" \
                1>&2
            return 2
        ;;
    esac

    printf '%s' "${required_commands[@]}"
}

# Check whether the required commands for the current distribution are available
#
# Parameters:
#
# * distro_id: The OS distribution identifier
# * distro_categories: The OS distribution categories
#
# Return values:
#
# * 0: All required commands are available
# * 1: At least one required command is not available
# * 2: Generic error
check_distro_specific_required_commands(){
    local distro_id="${1}"
    local distro_categories="${2}"

    local required_commands
    if ! required_commands="$(determine_required_commands "${distro_id}" "${distro_categories}")"; then
        return 2
    fi

    for command in ${required_commands}; do
        if ! check_command_existence "${command}"; then
            return 1
        fi
    done

    return 0
}

# Check whether the specified packages are installed
#
# Parameters:
#
# * packages...: Array of package names to check
# * package_manager: The package manager to use (e.g., pacman, dpkg, rpm)
#
# Return values:
#
# * 0: All packages are installed
# * 1: At least one package is not installed
# * 2: Generic error
check_packages_installed(){
    local -a packages=("$@")
    local package_manager="${!#}"

    if test "${#packages[@]}" -eq 0; then
        return 0
    fi

    case "${package_manager}" in
        pacman)
            if ! pacman -Q "${packages[@]}" &>/dev/null; then
                return 1
            fi
        ;;
        dpkg)
            if ! dpkg --status "${packages[@]}" &>/dev/null; then
                return 1
            fi
        ;;
        rpm)
            if ! rpm --query "${packages[@]}" &>/dev/null; then
                return 1
            fi
        ;;
        *)
            printf \
                '%s: Error: Unsupported package manager: %s.\n' \
                "${FUNCNAME[0]}" \
                "${package_manager}" \
                1>&2
            return 2
        ;;
    esac

    return 0
}

# Check whether the specified packages are installed (distribution-agnostic)
#
# Parameters:
#
# * packages...: Space-separated package names to check(or none)
#
# Return values:
#
# * 0: All packages are installed
# * 1: At least one package is not installed
# * 2: Generic error
check_distro_packages_installed(){
    local -a packages=("$@")

    if test "${#packages[@]}" -eq 0; then
        return 0
    fi

    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to determine the OS distribution identifier.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local distro_categories
    if ! distro_categories="$(get_distro_categories)"; then
        printf \
            '%s: Error: Unable to determine the OS distribution categories.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    case "${distro_categories}" in
        *debian*)
            if ! check_packages_installed "${packages[@]}" dpkg; then
                return 1
            fi
        ;;
        *rhel*)
            if ! check_packages_installed "${packages[@]}" rpm; then
                return 1
            fi
        ;;
        '')
            case "${ID}" in
                arch)
                    if ! check_packages_installed "${packages[@]}" pacman; then
                        return 1
                    fi
                ;;
                *)
                    printf \
                        '%s: Error: Unsupported OS distribution: %s.\n' \
                        "${FUNCNAME[0]}" \
                        "${distro_id}" \
                        1>&2
                    return 2
                ;;
            esac
        ;;
        *)
            printf \
                '%s: Error: Unsupported OS distribution categories: %s.\n' \
                "${FUNCNAME[0]}" \
                "${distro_categories}" \
                1>&2
            return 2
        ;;
    esac

    return 0
}

# print progress report message with additional styling
#
# Positional parameters:
#
# progress_msg: Progress report message text
# separator_char: Character used in the separator
print_progress(){
    local progress_msg="${1}"; shift
    local separator_char
    if test "${#}" -gt 0; then
        if test "${#1}" -ne 1; then
            printf -- \
                '%s: FATAL: The separator_char positional parameter only accept a single character as its argument.\n' \
                "${FUNCNAME[0]}" \
                1>&2
            exit 99
        fi
        separator_char="${1}"; shift
    else
        separator_char=-
    fi

    local separator_string=
    local -i separator_length

    # NOTE: COLUMNS shell variable is not available in
    # non-noninteractive shell
    # FIXME: This calculation is not correct for double-width characters
    # (e.g. 中文)
    # https://www.reddit.com/r/bash/comments/gynqa0/how_to_determine_character_width_for_special/
    separator_length="${#progress_msg}"

    # Reduce costly I/O operations
    local separator_block_string=
    local -i \
        separator_block_length=10 \
        separator_blocks \
        separator_remain_units
    separator_blocks="$(( separator_length / separator_block_length ))"
    separator_remain_units="$(( separator_length % separator_block_length ))"

    local -i i j k
    for ((i = 0; i < separator_block_length; i = i + 1)); do
        separator_block_string+="${separator_char}"
    done
    for ((j = 0; j < separator_blocks; j = j + 1)); do
        separator_string+="${separator_block_string}"
    done
    for ((k = 0; k < separator_remain_units; k = k + 1)); do
        separator_string+="${separator_char}"
    done

    printf \
        '\n%s\n%s\n%s\n' \
        "${separator_string}" \
        "${progress_msg}" \
        "${separator_string}"
}

# Refresh the RedHat software management system's local cache
#
# Return values:
#
# * 0: Cache refreshed successfully
# * 1: Prerequisite check failed
# * 2: Cache refresh failed
refresh_redhat_local_cache(){
    if ! check_running_user; then
        printf \
            '%s: Error: The running user check has failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! refresh_dnf_local_cache; then
        if ! refresh_yum_local_cache; then
            printf \
                '%s: Error: No suitable package manager commands are found.\n' \
                "${FUNCNAME[0]}" \
                1>&2
            return 1
        fi
    fi
}

# Refresh the DNF local cache
#
# Return values:
#
# * 0: Cache refreshed successfully
# * 1: DNF not available
# * 2: Cache refresh failed
refresh_dnf_local_cache(){
    if ! command -v dnf >/dev/null; then
        return 1
    fi

    if ! dnf makecache; then
        printf \
            '%s: Error: Unable to refresh the DNF local cache.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    return 0
}

# Refresh the YUM local cache
#
# Return values:
#
# * 0: Cache refreshed successfully
# * 1: YUM not available
# * 2: Cache refresh failed
refresh_yum_local_cache(){
    if ! command -v yum >/dev/null; then
        return 1
    fi

    if ! yum makecache; then
        printf \
            '%s: Error: Unable to refresh the YUM local cache.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 2
    fi

    return 0
}

# Check if required commands for Debian cache refresh are available
#
# Return values:
#
# * 0: All required commands are available
# * 1: At least one required command is not available
check_debian_cache_refresh_required_commands(){
    local -a required_commands=(
        # For determining the current time
        date

        # For determining the APT local cache creation time
        stat
    )
    local required_command_check_failed=false
    for command in "${required_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                '%s: Error: This function requires the "%s" command to be available in your command search PATHs.\n' \
                "${FUNCNAME[0]}" \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            '%s: Error: Required command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    return 0
}

# Get the modification time of the APT archive cache directory
#
# Standard output: Modification time in epoch format
# Return values:
#
# * 0: Time retrieved successfully
# * 1: Failed to retrieve time
get_apt_archive_cache_mtime(){
    if ! stat --format=%Y /var/cache/apt/archives; then
        printf \
            'Error: Unable to query the modification time of the APT software sources cache directory.\n' \
            1>&2
        return 1
    fi
}

# Get the current time in epoch format
#
# Standard output: Current time in epoch format
# Return values:
#
# * 0: Time retrieved successfully
# * 1: Failed to retrieve time
get_current_time_epoch(){
    if ! date +%s; then
        printf \
            'Error: Unable to query the current time.\n' \
            1>&2
        return 1
    fi
}

# Generate or refresh the Debian software management system's local cache
# when necessary
refresh_debian_local_cache(){
    if ! check_running_user; then
        printf \
            '%s: Error: The running user check has failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    if ! check_debian_cache_refresh_required_commands; then
        return 1
    fi

    local apt_archive_cache_mtime_epoch
    if ! apt_archive_cache_mtime_epoch="$(get_apt_archive_cache_mtime)"; then
        return 2
    fi

    local current_time_epoch
    if ! current_time_epoch="$(get_current_time_epoch)"; then
        return 2
    fi

    if test "$((current_time_epoch - apt_archive_cache_mtime_epoch))" -lt 86400; then
        printf \
            'Info: The last refresh time is less than 1 day, skipping...\n'
    else
        printf \
            'Info: Refreshing the APT local package cache...\n'
        if ! apt-get update; then
            printf \
                'Error: Unable to refresh the APT local package cache.\n' \
                1>&2
            return 2
        fi
    fi
}

refresh_package_manager_local_cache(){
    local distro_id="${1}"; shift
    local distro_categories="${1}"; shift

    print_progress \
        'Refreshing the package manager local cache...'

    if ! check_distro_specific_required_commands \
        "${distro_id}" \
        "${distro_categories}"; then
        printf \
            'Error: Package manager command check failed.\n' \
            1>&2
        return 1
    fi

    case "${distro_categories}" in
        *rhel*)
            if ! refresh_redhat_local_cache; then
                printf \
                    "Error: Unable to refresh the RedHat software management system's local cache.\\n" \
                    1>&2
                return 2
            fi
        ;;
        *debian*)
            if ! refresh_debian_local_cache; then
                printf \
                    "Error: Unable to refresh the Debian software management system's local cache.\\n" \
                    1>&2
                return 2
            fi
        ;;
        *)
            printf \
                'Error: The OS distribution category "%s" is not supported.\n' \
                "${FUNCNAME[0]}" \
                "${distro_id}" \
                1>&2
            exit 99
        ;;
    esac
}

switch_ubuntu_local_mirror(){
    print_progress 'Switching to use the local Ubuntu software archive mirror to minimize pacakge installation time...'

    if test -v CI; then
        printf \
            'Info: CI environment detected, will not attempt to change the software sources.\n'
    else
        local -a mirror_patch_dependency_pkgs=(
            # For sending HTTP request to third-party IP address lookup
            # services
            curl

            # For parsing IP address lookup response
            grep

            # For patching APT software source definition list
            sed
        )
        if ! check_distro_packages_installed "${mirror_patch_dependency_pkgs[@]}"; then
            printf \
                'Info: Installing the runtime dependencies packages for the mirror patching functionality...\n'
            if ! install_distro_packages "${mirror_patch_dependency_pkgs[@]}"; then
                printf \
                    'Error: Unable to install the runtime dependencies packages for the mirror patching functionality.\n' \
                    1>&2
                return 2
            fi
        fi

        printf \
            'Info: Detecting local region code...\n'
        local -a curl_opts=(
            # Return non-zero exit status when HTTP error occurs
            --fail

            # Do not show progress meter but keep error messages
            --silent
            --show-error
        )
        if ! ip_reverse_lookup_service_response="$(
                curl \
                    "${curl_opts[@]}" \
                    https://ipinfo.io/json
            )"; then
            printf \
                'Warning: Unable to detect the local region code(IP address reverse lookup service not available), falling back to the default.\n' \
                1>&2
            region_code=
        else
            local -a grep_opts=(
                --perl-regexp
                --only-matching
            )
            # shellcheck disable=SC2016
            if ! region_code="$(
                grep \
                    "${grep_opts[@]}" \
                    '(?<="country": ")[[:alpha:]]+' \
                    <<<"${ip_reverse_lookup_service_response}"
                )"; then
                printf \
                    'Warning: Unable to query the local region code, falling back to default.\n' \
                    1>&2
                region_code=
            else
                printf \
                    'Info: Local region code determined to be "%s".\n' \
                    "${region_code}"
            fi
        fi

        if test -n "${region_code}"; then
            # The returned region code is capitalized, fixing it.
            region_code="${region_code,,*}"

            printf \
                'Info: Checking whether the local Ubuntu archive mirror exists...\n'
            local -a curl_opts=(
                # Return non-zero exit status when HTTP error occurs
                --fail

                # Do not show progress meter but keep error messages
                --silent
                --show-error
            )
            if ! \
                curl \
                    "${curl_opts[@]}" \
                    "http://${region_code}.archive.ubuntu.com" \
                    >/dev/null; then
                printf \
                    "Warning: The local Ubuntu archive mirror doesn't seem to exist, falling back to default...\\n"
                region_code=
            else
                printf \
                    'Info: The local Ubuntu archive mirror service seems to be available, using it.\n'
            fi
        fi

        local sources_list_file_legacy=/etc/apt/sources.list
        local sources_list_file_deb822=/etc/apt/sources.list.d/ubuntu.sources
        local sources_list_file
        if test -e "${sources_list_file_deb822}"; then
            sources_list_file="${sources_list_file_deb822}"
        else
            sources_list_file="${sources_list_file_legacy}"
        fi
        if test -n "${region_code}" \
            && ! grep -q "${region_code}.archive.u" "${sources_list_file}"; then
            printf \
                'Info: Switching to use the local APT software repository mirror...\n'
            if ! \
                sed \
                    --regexp-extended \
                    --in-place \
                    "s@//([[:alpha:]]+\\.)?archive\\.ubuntu\\.com@//${region_code}.archive.ubuntu.com@g" \
                    "${sources_list_file}"; then
                printf \
                    'Error: Unable to switch to use the local APT software repository mirror.\n' \
                    1>&2
                return 2
            fi

            printf \
                'Info: Refreshing the local APT software archive cache...\n'
            if ! apt-get update; then
                printf \
                    'Error: Unable to refresh the local APT software archive cache.\n' \
                    1>&2
                return 2
            fi
        fi
    fi
}

# Check whether the required commands for running user check are available
#
# Return values:
#
# * 0: All required commands are available
# * 1: At least one required command is not available
check_running_user_required_commands(){
    local -a required_commands=(
        # For querying the current username
        whoami
    )
    local required_command_check_failed=false
    for command in "${required_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                '%s: Error: This function requires the "%s" command to be available in your command search PATHs.\n' \
                "${FUNCNAME[0]}" \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            '%s: Error: Required command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    return 0
}

# Check whether the running user is acceptable
#
# Return values:
#
# * 0: Check success
# * 1: Prerequisite failed
# * 2: Generic error
# * 3: Check failed
check_running_user(){
    if ! check_running_user_required_commands; then
        return 1
    fi

    printf 'Info: Checking running user...\n'
    if test "${EUID}" -ne 0; then
        printf \
            'Error: This program requires to be run as the superuser(root).\n' \
            1>&2
        return 2
    else
        local running_user
        if ! running_user="$(whoami)"; then
            printf \
                "Error: Unable to query the running user's username.\n" \
                1>&2
            return 2
        fi
        printf \
            'Info: The running user is acceptable(%s).\n' \
            "${running_user}"
    fi
}

# Install packages using the specified package manager
#
# Parameters:
#
# * packages...: Array of package names to install
# * package_manager: The package manager to use (e.g., apt-get, dnf, yum, pacman)
#
# Return values:
#
# * 0: Packages installed successfully
# * 1: Installation failed
# * 2: Generic error
install_packages(){
    local -a packages=("$@")
    local package_manager="${!#}"

    if test "${#packages[@]}" -eq 0; then
        return 0
    fi

    case "${package_manager}" in
        apt-get)
            # Silence warnings regarding unavailable debconf frontends
            export DEBIAN_FRONTEND=noninteractive
            if ! apt-get install -y "${packages[@]}"; then
                return 2
            fi
        ;;
        dnf)
            if ! dnf install -y "${packages[@]}"; then
                return 2
            fi
        ;;
        yum)
            if ! yum install -y "${packages[@]}"; then
                return 2
            fi
        ;;
        pacman)
            if ! pacman -S --noconfirm "${packages[@]}"; then
                return 2
            fi
        ;;
        *)
            printf \
                '%s: Error: Unsupported package manager: %s.\n' \
                "${FUNCNAME[0]}" \
                "${package_manager}" \
                1>&2
            return 2
        ;;
    esac

    return 0
}

# Install specified distribution packages
#
# Parameters:
#
# * packages...: Array of package names to install
#
# Return values:
#
# * 0: Operation completed successfully
# * 1: Prerequisite failed
# * 2: Generic error
# * 3: Install failed
install_distro_packages(){
    if test "${#}" -eq 0; then
        return 0
    fi

    local -a packages=("$@")

    if ! check_running_user; then
        printf \
            '%s: Error: The running user check has failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local distro_id
    if ! distro_id="$(get_distro_identifier)"; then
        printf \
            '%s: Error: Unable to determine the OS distribution identifier.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    local distro_categories
    if ! distro_categories="$(get_distro_categories)"; then
        printf \
            '%s: Error: Unable to determine the OS distribution categories.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        return 1
    fi

    case "${distro_categories}" in
        *debian*)
            if ! install_packages "${packages[@]}" apt-get; then
                return 1
            fi
        ;;
        *rhel*)
            if ! install_packages "${packages[@]}" dnf; then
                if ! install_packages "${packages[@]}" yum; then
                    return 1
                fi
            fi
        ;;
        '')
            case "${ID}" in
                arch)
                    if ! install_packages "${packages[@]}" pacman; then
                        return 1
                    fi
                ;;
                *)
                    printf \
                        '%s: Error: Unsupported OS distribution: %s.\n' \
                        "${FUNCNAME[0]}" \
                        "${distro_id}" \
                        1>&2
                    return 2
                ;;
            esac
        ;;
        *)
            printf \
                '%s: Error: Unsupported OS distribution categories: %s.\n' \
                "${FUNCNAME[0]}" \
                "${distro_categories}" \
                1>&2
            return 2
        ;;
    esac
}
