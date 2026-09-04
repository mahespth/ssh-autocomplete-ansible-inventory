# Bash completion for ssh using hosts and connection metadata
# from the Ansible inventory selected by $ANSIBLE_INVENTORY.
#
# Author:
#   Steve Maher
#
# Cache:
#   ${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion/
#
# Optional:
#   SSH_ANSIBLE_CACHE_TTL=300
#
# Cache format (tab-separated):
#   inventory_hostname    ansible_host    ansible_user    ansible_connection

_ssh_ansible_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"


# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

_ssh_ansible_hash()
{
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 | awk '{print $NF}'
    else
        return 1
    fi
}


_ssh_ansible_mtime()
{
    local file="$1"

    # GNU stat
    stat -c %Y "$file" 2>/dev/null && return 0

    # BSD/macOS stat
    stat -f %m "$file" 2>/dev/null
}


# ---------------------------------------------------------------------------
# Cache handling
# ---------------------------------------------------------------------------

_ssh_ansible_inventory_cache_key()
{
    local inventory="${ANSIBLE_INVENTORY:-}"

    [[ -n "$inventory" ]] || return 1

    printf '%s' "$inventory" | _ssh_ansible_hash
}


_ssh_ansible_cache_file()
{
    local key

    key=$(_ssh_ansible_inventory_cache_key) || return 1

    printf '%s/%s.hosts\n' "$_ssh_ansible_cache_dir" "$key"
}


_ssh_ansible_cache_expired()
{
    local cache="$1"
    local ttl="${SSH_ANSIBLE_CACHE_TTL:-300}"
    local now
    local cache_mtime

    [[ -e "$cache" ]] || return 0

    # A TTL <= 0 means always refresh.
    if (( ttl <= 0 )); then
        return 0
    fi

    now=$(date +%s)
    cache_mtime=$(_ssh_ansible_mtime "$cache") || return 0

    (( now - cache_mtime >= ttl ))
}


_ssh_ansible_inventory_changed()
{
    local cache="$1"
    local inventory="${ANSIBLE_INVENTORY:-}"
    local path

    [[ -e "$cache" ]] || return 0

    # ANSIBLE_INVENTORY can contain multiple inventory sources.
    #
    # For files:
    #   refresh if the file is newer than the cache.
    #
    # For directories:
    #   refresh if any file underneath the directory is newer.
    while IFS= read -r path; do
        [[ -n "$path" ]] || continue

        if [[ -f "$path" ]]; then
            [[ "$path" -nt "$cache" ]] && return 0

        elif [[ -d "$path" ]]; then
            if find "$path" -type f -newer "$cache" -print -quit 2>/dev/null |
                grep -q .
            then
                return 0
            fi
        fi

    done < <(printf '%s' "$inventory" | tr ':' '\n')

    return 1
}


_ssh_ansible_update_cache()
{
    local cache="$1"
    local tmp="${cache}.$$"

    mkdir -p "$_ssh_ansible_cache_dir" || return 1

    # ansible-inventory --list returns the resolved inventory including
    # inherited group/host variables in _meta.hostvars.
    #
    # Cache fields:
    #
    #   inventory hostname
    #   connection address
    #   connection user
    #   connection plugin
    #
    # For SSH user selection we prefer:
    #
    #   ansible_ssh_user
    #   ansible_user
    #   ansible_winrm_user
    #
    # The WinRM variable is retained as a fallback because Windows hosts
    # may have their login identity expressed using that variable even if
    # they are also reachable using OpenSSH.

    if ansible-inventory --list 2>/dev/null |
        python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

hostvars = data.get("_meta", {}).get("hostvars", {})

hosts = set(hostvars.keys())

# Also inspect group host lists in case an inventory implementation does
# not populate _meta.hostvars completely.
for name, group in data.items():
    if name == "_meta" or not isinstance(group, dict):
        continue

    group_hosts = group.get("hosts", [])

    if isinstance(group_hosts, list):
        hosts.update(group_hosts)


def clean(value):
    if value is None:
        return ""

    # Cache is TSV, so prevent embedded tabs/newlines from corrupting it.
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")


for host in sorted(hosts):
    variables = hostvars.get(host, {})

    if not isinstance(variables, dict):
        variables = {}

    connection = variables.get("ansible_connection", "")

    # SSH-specific values take precedence for an SSH completion.
    address = (
        variables.get("ansible_ssh_host")
        or variables.get("ansible_host")
        or variables.get("ansible_winrm_host")
        or ""
    )

    user = (
        variables.get("ansible_ssh_user")
        or variables.get("ansible_user")
        or variables.get("ansible_winrm_user")
        or ""
    )

    print(
        "{}\t{}\t{}\t{}".format(
            clean(host),
            clean(address),
            clean(user),
            clean(connection),
        )
    )
' > "$tmp"
    then
        mv "$tmp" "$cache"
        return 0
    fi

    rm -f "$tmp"
    return 1
}


_ssh_ansible_ensure_cache()
{
    local cache

    cache=$(_ssh_ansible_cache_file) || return 1

    if _ssh_ansible_cache_expired "$cache" ||
       _ssh_ansible_inventory_changed "$cache"
    then
        # If refresh fails but an old cache exists, keep using the old
        # cache rather than breaking shell completion.
        _ssh_ansible_update_cache "$cache" || {
            [[ -r "$cache" ]] && return 0
            return 1
        }
    fi

    [[ -r "$cache" ]]
}


# ---------------------------------------------------------------------------
# Inventory data access
# ---------------------------------------------------------------------------

_ssh_ansible_hosts()
{
    local cache

    [[ -n "${ANSIBLE_INVENTORY:-}" ]] || return 0

    _ssh_ansible_ensure_cache || return 0

    cache=$(_ssh_ansible_cache_file) || return 0

    cut -f1 "$cache"
}


_ssh_ansible_users()
{
    local cache

    [[ -n "${ANSIBLE_INVENTORY:-}" ]] || return 0

    _ssh_ansible_ensure_cache || return 0

    cache=$(_ssh_ansible_cache_file) || return 0

    cut -f3 "$cache" |
        grep -v '^$' |
        sort -u
}


_ssh_ansible_user_for_host()
{
    local host="$1"
    local cache

    [[ -n "$host" ]] || return 0

    # ssh may have been supplied user@hostname.
    host="${host#*@}"

    _ssh_ansible_ensure_cache || return 0

    cache=$(_ssh_ansible_cache_file) || return 0

    # Match either inventory_hostname or ansible_host.
    awk -F '\t' -v host="$host" '
        ($1 == host || $2 == host) && $3 != "" {
            print $3
            exit
        }
    ' "$cache"
}


# ---------------------------------------------------------------------------
# SSH command-line parsing
# ---------------------------------------------------------------------------

_ssh_ansible_find_target_host()
{
    local i
    local word
    local end=$(( ${#COMP_WORDS[@]} - 1 ))

    for ((i = 1; i <= end; i++)); do

        # Do not treat the word currently being completed as an existing
        # hostname.
        if (( i == COMP_CWORD )); then
            continue
        fi

        word="${COMP_WORDS[i]}"

        case "$word" in

            --)
                # First word after -- is the target host.
                ((i++))

                if (( i <= end && i != COMP_CWORD )); then
                    printf '%s\n' "${COMP_WORDS[i]}"
                fi

                return
                ;;

            # SSH options which take a separate argument.
            -[BbCcDEeFIiJLlmOoPpQRSWw])
                ((i++))
                continue
                ;;

            # Same options with their argument attached, e.g.
            # -p22, -lubuntu, -i~/.ssh/key.
            -[BbCcDEeFIiJLlmOoPpQRSWw]?*)
                continue
                ;;

            -*)
                continue
                ;;

            *)
                printf '%s\n' "$word"
                return
                ;;
        esac
    done
}


_ssh_ansible_previous_option_takes_value()
{
    local previous="$1"

    case "$previous" in
        -[BbCcDEeFIiJLlmOoPpQRSWw])
            return 0
            ;;
    esac

    return 1
}


# ---------------------------------------------------------------------------
# Bash completion
# ---------------------------------------------------------------------------

_ssh_ansible_complete()
{
    local cur
    local prev
    local host
    local user
    local user_prefix
    local hostpart
    local i

    local -a hosts

    COMPREPLY=()

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev=""

    if (( COMP_CWORD > 0 )); then
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    fi


    # -----------------------------------------------------------------------
    # ssh -l USER HOST
    # -----------------------------------------------------------------------

    if [[ "$prev" == "-l" ]]; then

        # If a hostname exists elsewhere on the command line, return only
        # the user configured for that host.
        #
        # Examples:
        #
        #   ssh web01 -l <TAB>
        #   ssh -l <TAB> web01
        #
        host=$(_ssh_ansible_find_target_host)

        if [[ -n "$host" ]]; then
            user=$(_ssh_ansible_user_for_host "$host")

            if [[ -n "$user" ]]; then
                mapfile -t COMPREPLY < <(
                    compgen -W "$user" -- "$cur"
                )

                return 0
            fi
        fi

        # No hostname is known yet, so return all unique configured users.
        #
        # Example:
        #
        #   ssh -l <TAB>
        #
        mapfile -t COMPREPLY < <(
            compgen -W "$(_ssh_ansible_users)" -- "$cur"
        )

        return 0
    fi


    # -----------------------------------------------------------------------
    # Don't offer hosts while completing another SSH option argument.
    # -----------------------------------------------------------------------

    if _ssh_ansible_previous_option_takes_value "$prev"; then
        return 0
    fi


    # -----------------------------------------------------------------------
    # Don't offer hostnames after the target host has already been supplied.
    #
    # Example:
    #
    #   ssh web01 uname <TAB>
    #
    # At this point we are completing the remote command, not the host.
    # -----------------------------------------------------------------------

    host=$(_ssh_ansible_find_target_host)

    if [[ -n "$host" ]]; then
        return 0
    fi


    # -----------------------------------------------------------------------
    # Don't try hostname completion for SSH options.
    # -----------------------------------------------------------------------

    [[ "$cur" == -* ]] && return 0


    mapfile -t hosts < <(_ssh_ansible_hosts)

    (( ${#hosts[@]} )) || return 0


    # -----------------------------------------------------------------------
    # user@hostname completion
    #
    # Example:
    #
    #   ssh ubuntu@web<TAB>
    # -----------------------------------------------------------------------

    if [[ "$cur" == *@* ]]; then
        user_prefix="${cur%@*}@"
        hostpart="${cur#*@}"

        mapfile -t COMPREPLY < <(
            compgen -W "${hosts[*]}" -- "$hostpart"
        )

        for i in "${!COMPREPLY[@]}"; do
            COMPREPLY[$i]="${user_prefix}${COMPREPLY[$i]}"
        done

        return 0
    fi


    # -----------------------------------------------------------------------
    # Normal hostname completion
    #
    # Example:
    #
    #   ssh web<TAB>
    # -----------------------------------------------------------------------

    mapfile -t COMPREPLY < <(
        compgen -W "${hosts[*]}" -- "$cur"
    )
}


complete -F _ssh_ansible_complete ssh
