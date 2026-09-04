# SSH Ansible Inventory Bash Completion


Bash completion for `ssh` using hostnames from an Ansible inventory, author Steve Maher.

The completion reads the inventory configured by the `ANSIBLE_INVENTORY` environment variable and uses `ansible-inventory --list` to discover available hosts.

To avoid running `ansible-inventory` every time you press `TAB`, discovered hosts are cached locally.

## Features

* Completes SSH hostnames from Ansible inventory
* Uses the `ANSIBLE_INVENTORY` environment variable
* Supports static and dynamic Ansible inventories
* Caches inventory hosts for faster completion
* Automatically refreshes the cache when inventory files change
* Configurable cache TTL
* Supports `user@hostname` completion

Example:

```bash
ssh web<TAB>
```

may complete to:

```text
web01
web02
web03
```

Usernames are also supported:

```bash
ssh ubuntu@web<TAB>
```

may complete to:

```text
ubuntu@web01
ubuntu@web02
ubuntu@web03
```

## Requirements

The following commands must be available:

* Bash
* Ansible
* `ansible-inventory`
* Python 3
* `sha256sum`
* `stat`

Check that Ansible inventory works before installing the completion:

```bash
ansible-inventory --list
```

## Installation

Create a directory for Bash completion scripts if one does not already exist:

```bash
mkdir -p ~/.bash_completion.d
```

Copy the completion script into it:

```bash
cp ssh-ansible-completion.bash ~/.bash_completion.d/ssh-ansible
```

Then load it from your `~/.bashrc`:

```bash
source ~/.bash_completion.d/ssh-ansible
```

Reload your shell:

```bash
source ~/.bashrc
```

Alternatively, open a new terminal.

## Configure the Ansible Inventory

Set the `ANSIBLE_INVENTORY` environment variable to the inventory you want to use.

For example:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
```

You will normally want to add this to your `~/.bashrc`:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
```

Then reload it:

```bash
source ~/.bashrc
```

The value is passed implicitly to `ansible-inventory`, so the completion uses the same inventory Ansible itself would use.

You can verify the inventory with:

```bash
ansible-inventory --graph
```

or:

```bash
ansible-inventory --list
```

## Usage

Once installed, use SSH normally.

Type part of a hostname and press `TAB`:

```bash
ssh web<TAB>
```

If the inventory contains:

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

You can also include the SSH username:

```bash
ssh ubuntu@web<TAB>
```

which will offer:

```text
ubuntu@web01
ubuntu@web02
ubuntu@web03
```

## Caching

Running:

```bash
ansible-inventory --list
```

can be relatively expensive, especially when using dynamic inventory plugins.

For that reason, the completion caches the discovered hostnames.

By default, the cache is stored under:

```text
~/.cache/ssh-ansible-completion/
```

If `XDG_CACHE_HOME` is set, the cache is stored under:

```text
$XDG_CACHE_HOME/ssh-ansible-completion/
```

Each value of `ANSIBLE_INVENTORY` gets its own cache file.

This means switching between inventories will not overwrite the cached hosts for another inventory.

## Cache Lifetime

The default cache lifetime is:

```text
300 seconds
```

or five minutes.

You can change this using the `SSH_ANSIBLE_CACHE_TTL` environment variable.

For example, to refresh every minute:

```bash
export SSH_ANSIBLE_CACHE_TTL=60
```

To cache for one hour:

```bash
export SSH_ANSIBLE_CACHE_TTL=3600
```

You can add this setting to your `~/.bashrc`:

```bash
export SSH_ANSIBLE_CACHE_TTL=300
```

## Inventory Change Detection

The completion does not rely only on the cache TTL.

If a local inventory source is newer than the cache file, the host cache is refreshed automatically.

For example, after editing:

```text
inventory/prod/hosts.yml
```

the next SSH completion will regenerate the cache.

The TTL is still useful for dynamic inventory sources where the remote inventory may change even when the local inventory configuration does not.

## Clear the Cache

To force the inventory to be rebuilt on the next completion, remove the cache:

```bash
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"
```

Then type:

```bash
ssh <TAB>
```

The completion will run `ansible-inventory` and create a new cache.

## Multiple Inventories

`ANSIBLE_INVENTORY` can point to different inventories depending on your current environment.

For example:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/dev"
```

or:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/prod"
```

The completion creates a different cache entry for each inventory value.

You can therefore switch inventories without manually clearing the cache.

For example:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/dev"
ssh web<TAB>
```

then:

```bash
export ANSIBLE_INVENTORY="$HOME/ansible/inventory/prod"
ssh web<TAB>
```

Each inventory will use its own cached host list.

## Testing

Check that the environment variable is set:

```bash
echo "$ANSIBLE_INVENTORY"
```

Check that Ansible can read it:

```bash
ansible-inventory --graph
```

Check the hosts returned by the completion directly:

```bash
_ssh_ansible_hosts
```

You should see one hostname per line.

For example:

```text
db01
db02
redis01
web01
web02
web03
```

Then try Bash completion:

```bash
ssh web<TAB>
```

## Troubleshooting

### No hosts are returned

Check that `ANSIBLE_INVENTORY` is set:

```bash
echo "$ANSIBLE_INVENTORY"
```

Then verify that Ansible can load the inventory:

```bash
ansible-inventory --list
```

If that command fails, the completion will not be able to discover hosts.

### Completion does not run

Check that the completion file has been sourced:

```bash
type _ssh_ansible_complete
```

You should see that `_ssh_ansible_complete` is a shell function.

You can manually load it with:

```bash
source ~/.bash_completion.d/ssh-ansible
```

### Inventory changes are not appearing

Remove the cache:

```bash
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"
```

Alternatively, reduce the cache TTL:

```bash
export SSH_ANSIBLE_CACHE_TTL=30
```

### Dynamic inventory is stale

Dynamic inventories may change without the local inventory configuration file changing.

Use a shorter TTL for these environments:

```bash
export SSH_ANSIBLE_CACHE_TTL=60
```

### Existing SSH completion disappeared

The completion currently registers itself with:

```bash
complete -F _ssh_ansible_complete ssh
```

This replaces the existing Bash completion function for `ssh`.

If your system's `bash-completion` package already provides SSH completion, features such as completion from:

```text
~/.ssh/config
~/.ssh/known_hosts
```

or completion of some SSH options may no longer be available.

A future version could extend the system `_ssh` completion function instead of replacing it, allowing Ansible inventory hosts and standard SSH completion to work together.

## Suggested `.bashrc` Configuration

A typical configuration might look like:

```bash
export ANSIBLE_INVENTORY="$HOME/git/infra/ansible/inventory/prod"
export SSH_ANSIBLE_CACHE_TTL=300

source "$HOME/.bash_completion.d/ssh-ansible"
```

## Uninstall

Remove the completion script:

```bash
rm ~/.bash_completion.d/ssh-ansible
```

Remove the cache:

```bash
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/ssh-ansible-completion"
```

Then remove the corresponding `source` line and environment variables from your `~/.bashrc`.

Open a new terminal or reload Bash:

```bash
source ~/.bashrc
```

## License

Use and modify as required for your environment.
