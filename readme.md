# pqclid

Progress Quest CLI installer and configurer to run as a daemon.
Also includes a web interface displaying current status.

## Principle

### Running `pqcli` in the background

The following command:

```sh
tmux -S ~/.tmux_pqcli_socket new-session -d -s pqcli "pqcli --load-save 1"
```

creates a `tmux` session:
* Running `pqcli`
  * Loading save 1
* Using the socket `~/.tmux_pqcli_socket`
* Running in the background (detached)

You can verify the background process is running using this command:

```sh
tmux -S ~/.tmux_pqcli_socket ls
```

which should output something like this:

```
pqcli: 1 windows (created Tue Dec 30 22:14:08 2025)
```

### Peeking into the `pqcli` session

This command:

```sh
tmux -S ~/.tmux_pqcli_socket attach-session -t pqcli
```

lets you "open" up the background running `pqcli` and see the status.

Send it back to the background using the key combination:
* `Ctrl+B`, then `D`.

#### Alternative

This command can also be used if there's only one session at `.tmux_pqcli_socket`:

* `tmux -S ~/.tmux_pqcli_socket attach`
* Or just `tmux -S ~/.tmux_pqcli_socket a`


### Taking a "screenshot" of the current `pqcli` session

This command:

```sh
tmux -S ~/.tmux_pqcli_socket capture-pane -t pqcli -pJ > capture.txt
```

* **Doesn't** open the `tmux` session
* Captures the current `pqcli` terminal window / ncurses screen (i.e. in ASCII characters)
* Saves the captured characters from the background session into the file `capture.txt`

`cat capture.txt` could then be used to peek at the current state of the program.

## Web Interface

The `ruby` code in this repo does these things:

1. Capture from the `pqcli` instance running in a background (detached) `tmux` session, and save this to `.capture`
2. Parse `.capture` to obtain the current status (level, inventory, plot, etc.)
3. Format it and display it all in a snazzy webpage
4. Serve the user the webpage with all the data at port `11662`

If the webapp is running, i.e. with

```sh
bundle exec ruby app.rb
```

You can go to `localhost:11662` to get a snapshot of your character's current situation.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/robotitect/pqclid/main/install.sh | sh
```

This installs (if not already present):

1. `tmux`
	* This is used to run the `pqcli` interface in the background.
2. `pipx`
	* This is used to install `pqcli` without messing with Python environments
3. `git`
4. `curl`
5. `ruby`
	* 3.2.4 compatible version
6. `pqcli` (via `pipx`)

It will then startup `pqcli`'s interface once. You will need to create a character at this point and exit out of the program. This creates an initial save that the daemon picks up and loads from.

After it sees you've quit `pqcli`, it installs the daemon (`systemd` service), which runs a perpetual `tmux` session that houses a `pqcli` instance. This should survive:
* Crashing
* Power cycling
* Manual termination (`tmux kill-session`)

(Survive meaning that, if the session ever stops, it will restart the session, creating a new `pqcli` instance, and load from the save file.)


## TODO
- [ ] Prompt the user about creating a character in install script (3s timeout)
- [ ] Ship/install a local version of (needs to support different CPU architectures)
	* `pipx` OR `pqcli`
		* `git` may also be needed
	* `tmux`
	* `ruby` (3.4.7), gems:
		* `sinatra`
		* `puma`
		* `rackup`
		* `roman-numerals`
- [ ] Create a deploy script / daemon for the web interface
	* calling these commands to install the gems
		* `bundle config set --local path 'vendor/bundle'`
		* `bundle install --deployment --without development test`
	* and this one to run the server
		* `bundle exec ruby app.rb`

### Bugs
- [x] Divide by zero error in PqCliParse#calc_xp

### Tests

- [ ] Different package managers
	- [ ] Ubuntu (`apt`)
	- [ ] Fedora (`dnf`)
	- [ ] Manjaro (`pacman`)
- [ ] Different architectures
	- [ ] `x86_64`
	- [ ] `aarch64`
	- [ ] `armv7` (RPis)
	- [ ] `armv6` (RPi 1 / Zero)

### Wishlist
- [ ] Create command for attaching to the instance
- [ ] Create command for displaying a snapshot of the instance
- [ ] Add appropriate emojis to inventory items based on text classification
	- [ ] Record inventory items on each screengrab as data

### Completed
- [x] Use `pipx` to install pqcli (from github repo)
- [x] Web interface
- [x] Add text explaining how to use attach/detach from the session
