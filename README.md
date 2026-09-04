# SSH Ansible Inventory Bash Completion

Bash completion for `ssh` using hosts and connection information from an Ansible inventory by Steve Maher.

The completion uses the inventory selected by the `ANSIBLE_INVENTORY` environment variable and obtains the resolved inventory using:

```bash
ansible-inventory --list
```

The results are cached locally so that `ansible-inventory` does not need to run every time `TAB` is pressed.

## Features

* Complete SSH hostnames from Ansible inventory
* Uses the `ANSIBLE_INVENTORY` environment variable
* Supports static and dynamic Ansible inventories
* Caches inventory information for fast completion
* Automatically refreshes when local inventory files change
* Configurable cache TTL
* Supports `user@hostname` completion
* Completes users for the SSH `-l` option
* Reads `ansible_user`
* Reads `ansible_ssh_user`
* Falls back to `ansible_winrm_user` for Windows inventories
* Records `ansible_host` and `ansible_connection` for future use
* Keeps using the previous cache if an inventory refresh temporarily fails

## Example

Given an Ansible inventory containing:

```yaml
all:
  hosts:
    web01:
      ansible_host: 10.20.1.10
      ansible_user: ubuntu

    web02:
      ansible_host: 10.20.1.11
      ansible_ssh_user: deploy

    win01:
      ansible_host: 10.20.2.10
      ansible_connection: winrm
      ansible_winrm_user: Administrator
```

typing:

```bash
ssh web<TAB>
```

will offer:

```text
web01
web02
```

You can also use normal `user@host` syntax:

```bash
ssh ubuntu@web<TAB>
```

which can complete to:

```text
ubuntu@web01
ubuntu@web02
```

The completion also understands SSH's `-l` option.

For example:

```bash
ssh web01 -l <TAB>
```

will offer:

```text
ubuntu
```

If the host is not yet known:

```bash
ssh -l <TAB>
```

the completion displays all unique users discovered in the inventory, for example:

```text
Administrator
deploy
ubuntu
```

## Requirements

The following are required:

* Bash
* Ansible
* `ansible-inventory`
* Python 3
* `find`
* `awk`
* `grep`
* `sort`

One of the following SHA-256 utilities must also be available:

* `sha256sum`
* `shasum`
* `openssl`

The script supports both GNU and BSD/macOS versions of `stat`.

Before installing the completion, verify that Ansible can read your inventory:

```bash
ansible-inventory --list
```

You can also inspect it using:

```bash
ansible-inventory --graph
```

## Installation

Create a directory for personal Bash completion scripts:

```bash
mkdir -p ~/.bash_completion.d
```

Copy the script into it:

```bash
cp ssh-ansible-completion.bash ~/.bash_completion.d/ssh-ansible
```

Add the following to `~/.bashrc`:

```bash
source "$HOME/.bash_completion.d/ssh-ansible"
```

Reload Bash:

```bash
source ~/.bashrc
```

Alternatively, open a new terminal.

## Configure the Inventory

Set `ANSIBLE_INVENTORY` to the Ansible inventory you want the completion to use.

For example:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
```

You will normally want to place this in `~/.bashrc`:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
```

Reload the shell:

```bash
source ~/.bashrc
```

Verify the value:

```bash
echo "$ANSIBLE_INVENTORY"
```

Then check that Ansible can resolve it:

```bash
ansible-inventory --graph
```

## Host Completion

Type part of an inventory hostname and press `TAB`.

For example:

```bash
ssh web<TAB>
```

Given hosts:

```text
web01
web02
web03
db01
db02
```

Bash will offer:

```text
web01
web02
web03
```

The inventory hostname is used for completion rather than the value of `ansible_host`.

For example:

```yaml
web01:
  ansible_host: 10.20.1.10
```

is completed as:

```bash
ssh web01
```

This allows SSH configuration, DNS, ProxyJump configuration, or other tooling to decide how that inventory name should ultimately be reached.

The resolved `ansible_host` is still stored in the cache and is used when looking up the Ansible user for a host.

## `user@host` Completion

Normal SSH `user@host` syntax is supported.

For example:

```bash
ssh ubuntu@web<TAB>
```

can complete to:

```text
ubuntu@web01
ubuntu@web02
ubuntu@web03
```

The username you have already entered is retained.

The script does not currently replace the username in `user@host` syntax with the Ansible-configured username automatically.

For selecting the configured Ansible user, use the `-l` completion described below.

## SSH `-l` User Completion

The SSH `-l` option specifies the login username:

```bash
ssh -l ubuntu web01
```

The completion can obtain this username from Ansible inventory variables.

### Host Already Known

If the hostname appears before `-l`:

```bash
ssh web01 -l <TAB>
```

and the inventory contains:

```yaml
web01:
  ansible_user: ubuntu
```

the completion will offer:

```text
ubuntu
```

It also works when the hostname exists later on the command line:

```bash
ssh -l <TAB> web01
```

### Host Not Yet Known

With:

```bash
ssh -l <TAB>
```

there is no hostname available to determine which user should be selected.

In this situation the completion returns all unique users discovered in the inventory.

For example:

```text
Administrator
deploy
ubuntu
```

You can continue typing to filter the results:

```bash
ssh -l dep<TAB>
```

which can complete to:

```text
deploy
```

## Ansible User Variables

The completion recognises these Ansible variables:

```text
ansible_ssh_user
ansible_user
ansible_winrm_user
```

For SSH completion, the lookup order is:

```text
ansible_ssh_user
ansible_user
ansible_winrm_user
```

This means an explicitly configured SSH user takes precedence over the generic Ansible connection user.

For example:

```yaml
web01:
  ansible_user: automation
  ansible_ssh_user: ubuntu
```

will result in:

```bash
ssh web01 -l <TAB>
```

completing to:

```text
ubuntu
```

### Windows Hosts

Windows inventories commonly contain:

```yaml
win01:
  ansible_connection: winrm
  ansible_user: Administrator
```

or:

```yaml
win01:
  ansible_connection: winrm
  ansible_winrm_user: Administrator
```

Both forms are recognised.

This can also be useful in environments where Windows hosts are normally managed through WinRM but additionally have OpenSSH enabled.

## Cache

Running:

```bash
ansible-inventory --list
```

can be relatively expensive, particularly with dynamic inventory plugins.

For this reason the completion caches the resolved inventory information.

The default cache location is:

```text
~/.cache/ssh-ansible-completion/
```

If `XDG_CACHE_HOME` is configured, the location is:

```text
$XDG_CACHE_HOME/ssh-ansible-completion/
```

For example:

```text
~/.cache/ssh-ansible-completion/
└── 918fa53b....hosts
```

Each different value of `ANSIBLE_INVENTORY` receives a separate cache file.

## Cache Contents

The cache is tab-separated and contains four fields:

```text
inventory_hostname    ansible_host    ansible_user    ansible_connection
```

For example:

```text
web01    10.20.1.10    ubuntu         ssh
web02    10.20.1.11    deploy         ssh
win01    10.20.2.10    Administrator  winrm
```

This information is generated from the resolved output of:

```bash
ansible-inventory --list
```

The cache is an implementation detail and does not normally need to be edited manually.

## Cache Lifetime

The default cache lifetime is:

```text
300 seconds
```

or five minutes.

Configure it using:

```bash
SSH_ANSIBLE_CACHE_TTL
```

For example, refresh at most once every minute:

```bash
export SSH_ANSIBLE_CACHE_TTL=60
```

Refresh at most once every hour:

```bash
export SSH_ANSIBLE_CACHE_TTL=3600
```

A value of zero causes the inventory to be refreshed whenever completion requires it:

```bash
export SSH_ANSIBLE_CACHE_TTL=0
```

A typical setting is:

```bash
export SSH_ANSIBLE_CACHE_TTL=300
```

## Inventory Change Detection

The completion does not rely solely on the cache TTL.

When `ANSIBLE_INVENTORY` points to local files, the cache is refreshed if an inventory file is newer than the cache.

For inventory directories, files below the directory are checked recursively.

For example:

```text
inventory/
└── prod/
    ├── hosts.yml
    ├── group_vars/
    │   └── all.yml
    └── host_vars/
        └── web01.yml
```

Changing any of these files will cause the inventory cache to be rebuilt on the next completion.

The TTL remains useful for dynamic inventories because their remote data can change without any local inventory file changing.

## Dynamic Inventory

Dynamic inventory plugins are supported because the completion does not parse inventory files directly.

Instead it uses:

```bash
ansible-inventory --list
```

This means AWS, Azure, VMware, custom inventory plugins, and other inventory sources can be used as long as `ansible-inventory` can resolve them normally.

For dynamic inventories, consider using a shorter cache TTL.

For example:

```bash
export SSH_ANSIBLE_CACHE_TTL=60
```

## Refresh Failure Behaviour

If the cache has expired and:

```bash
ansible-inventory --list
```

temporarily fails, the completion will continue using an existing cache if one is available.

For example, this can be useful if:

* a dynamic inventory API is temporarily unavailable
* VPN connectivity has dropped
* cloud credentials need refreshing
* DNS is temporarily unavailable

If no previous cache exists and inventory generation fails, no Ansible completions will be returned.

## Multiple Inventories

Different values of `ANSIBLE_INVENTORY` use different cache files.

For example:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/dev"
```

then:

```bash
ssh web<TAB>
```

uses the development inventory.

Switching to:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/prod"
```

causes completion to use a separate production cache.

You do not need to manually clear the cache when switching inventories.

## Testing

Check that the environment variable is configured:

```bash
echo "$ANSIBLE_INVENTORY"
```

Check the raw inventory:

```bash
ansible-inventory --list
```

Check the inventory graph:

```bash
ansible-inventory --graph
```

Check the hostnames returned by the completion:

```bash
_ssh_ansible_hosts
```

Example:

```text
db01
db02
web01
web02
win01
```

Check the users discovered by the completion:

```bash
_ssh_ansible_users
```

Example:

```text
Administrator
deploy
ubuntu
```

Check the configured user for a specific host:

```bash
_ssh_ansible_user_for_host web01
```

Example:

```text
ubuntu
```

The lookup also accepts the resolved `ansible_host`:

```bash
_ssh_ansible_user_for_host 10.20.1.10
```

Example:

```text
ubuntu
```

## Inspecting the Cache

Find the current cache file with:

```bash
_ssh_ansible_cache_file
```

For example:

```text
/home/user/.cache/ssh-ansible-completion/918fa53b....hosts
```

Inspect it with:

```bash
cat "$(_ssh_ansible_cache_file)"
```

or, for easier viewing:

```bash
column -s $'\t' -t "$(_ssh_ansible_cache_file)"
```

Example:

```text
web01  10.20.1.10  ubuntu         ssh
web02  10.20.1.11  deploy         ssh
win01  10.20.2.10  Administrator  winrm
```

## Clearing the Cache

Remove all cached inventories:

```bash
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"
```

The next completion will rebuild the cache.

To refresh only the currently selected inventory:

```bash
rm -f "$(_ssh_ansible_cache_file)"
```

Then trigger completion:

```bash
ssh <TAB>
```

## Troubleshooting

### No Hosts Are Returned

Check:

```bash
echo "$ANSIBLE_INVENTORY"
```

Then verify Ansible itself can load the inventory:

```bash
ansible-inventory --list
```

Finally test:

```bash
_ssh_ansible_hosts
```

### No Users Are Returned

Inspect the resolved Ansible host variables:

```bash
ansible-inventory --list
```

Look for one of:

```text
ansible_user
ansible_ssh_user
ansible_winrm_user
```

You can also test:

```bash
_ssh_ansible_users
```

and:

```bash
_ssh_ansible_user_for_host web01
```

### Completion Is Not Loaded

Check:

```bash
type _ssh_ansible_complete
```

You should see:

```text
_ssh_ansible_complete is a function
```

If not, load the script manually:

```bash
source ~/.bash_completion.d/ssh-ansible
```

### Inventory Changes Are Not Appearing

Force a cache refresh:

```bash
rm -f "$(_ssh_ansible_cache_file)"
```

Alternatively reduce the TTL:

```bash
export SSH_ANSIBLE_CACHE_TTL=30
```

### Dynamic Inventory Is Stale

Dynamic inventory can change without any local file changing.

Reduce the cache TTL:

```bash
export SSH_ANSIBLE_CACHE_TTL=60
```

### Inventory Refresh Is Failing

Run:

```bash
ansible-inventory --list
```

directly.

The completion deliberately hides errors from this command because printing errors while Bash is attempting completion would interfere with the shell prompt.

Running the command manually will show the actual Ansible error.

## Existing Bash SSH Completion

The script registers itself using:

```bash
complete -F _ssh_ansible_complete ssh
```

This replaces any existing Bash programmable completion registered for `ssh`.

As a result, completion supplied by the standard `bash-completion` package for things such as SSH options, `~/.ssh/config`, and `known_hosts` may no longer be available.

The Ansible completion currently focuses on:

```text
ssh HOST
ssh USER@HOST
ssh -l USER HOST
```

A future enhancement could integrate the Ansible host list into the standard Bash `_ssh` completion rather than replacing it.

## Suggested `.bashrc`

A typical configuration is:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
export SSH_ANSIBLE_CACHE_TTL=300

source "$HOME/.bash_completion.d/ssh-ansible"
```

Reload it with:

```bash
source ~/.bashrc
```

## Uninstall

Remove the completion:

```bash
rm ~/.bash_completion.d/ssh-ansible
```

Remove the cache:

```bash
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"
```

Remove the corresponding configuration from `~/.bashrc`:

```bash
export ANSIBLE_INVENTORY=...
export SSH_ANSIBLE_CACHE_TTL=...
source "$HOME/.bash_completion.d/ssh-ansible"
```

Then open a new terminal or reload Bash:

```bash
source ~/.bashrc
```

## License

Use, modify, and redistribute as appropriate for your environment.
