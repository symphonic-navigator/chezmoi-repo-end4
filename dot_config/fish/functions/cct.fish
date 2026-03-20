function cct --wraps='claude --dangerously-skip-permissions' --description 'claude code with --dangerously-skip-permissions and telegram access'
    claude --dangerously-skip-permissions --channels plugin:telegram@claude-plugins-official $argv
end
