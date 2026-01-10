function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

	# 1. Environment Variables
	set -gx PATH $HOME/bin $HOME/.local/bin /usr/local/bin $PATH $HOME/.dotnet/tools
	set -gx EDITOR nvim
	set -gx LANG en_US.UTF-8
	set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket

	# 2. Starship Prompt (must come early)
	if command -v starship >/dev/null 2>&1
	    starship init fish | source
	else
	    echo "❌ starship not found. Please install starship."
	end

	# 3. zoxide Integration
	if command -v zoxide >/dev/null 2>&1
	    zoxide init fish | source
	else
	    echo "❌ zoxide not found. Please install zoxide."
	end

	# 4. Abbreviations (instead of aliases)
	abbr -a vim nvim
	abbr -a v nvim
	abbr -a reset 'clear; source ~/.config/fish/config.fish; hyprctl reload'
	abbr -a yay 'yay --answerclean All --answerdiff N --answeredit N --answerupgrade Y --removemake --noconfirm'
	abbr -a ghc 'gh copilot'
	abbr -a ghce 'gh copilot explain'
	abbr -a ghcs 'gh copilot suggest'
	abbr -a wlc wl-copy
	abbr -a wlp wl-paste
	abbr -a l ls -l --icons

	# chezmoi helpers
	function cea --description "chezmoi edit + apply + reload"
	    chezmoi edit $argv && chezmoi apply && hyprctl reload
	end

	function cear --description "chezmoi edit + apply + full reset"
	    chezmoi edit $argv && chezmoi apply && clear && source ~/.config/fish/config.fish && hyprctl reload
	end

	abbr -a cdc 'cd ~/.local/share/chezmoi'

	# 5. fzf Enhancements (with fzf.fish plugin – install via fisher!)
	# fzf.fish already provides great history search (Ctrl+R), dir jump etc.
	# If you want custom: see https://github.com/PatrickF1/fzf.fish

	# 6. kitty ssh kitten override
	if set -q KITTY_WINDOW_ID
	    function ssh --wraps ssh
		kitten ssh $argv
	    end
	else
	    abbr -a ssh command ssh
	end

	# 7. Local overrides (if you have them)
	if test -f ~/.local-env.fish
	    source ~/.local-env.fish
	end

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias pamcan pacman
    alias ls 'eza --icons'
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias q 'qs -c ii'

    direnv hook fish | source

end


