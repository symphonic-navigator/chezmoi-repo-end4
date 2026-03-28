function ccglm --wraps='ollama launch claude --model glm-5:cloud -- --dangerously-skip-permissions' --description 'alias ccglm ollama launch claude --model glm-5:cloud -- --dangerously-skip-permissions $argv
'
    ollama launch claude --model glm-5:cloud -- --dangerously-skip-permissions $argv
end
