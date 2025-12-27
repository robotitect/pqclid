# pqclid

Progress Quest CLI install and configuration to run as a daemon.

## TODO
- [ ] Test the install script on Debian VM
- [ ] Add text explaining how to use attach/detach from the session
- [ ] Install script support on other distros
	- [ ] Fedora
	- [ ] Arch
- [ ] Use `pipx` to install pqcli (from github repo)
- [ ] Support for creating a character in install script
- [ ] Install script installs its own version of Python and tmux and uses those
- [ ] Create command for attaching to the instance
- [ ] Create command for displaying a snapshot of the instance
- [x] Web interface

### Web interface notes
* This command "screenshots" the session
	* `tmux capture-pane -t pqcli -pJ`
	* Can be piped to a file or `cat`
* Use the above to serve a webpage (sinatra) that just shows this
	* Refreshes every second
