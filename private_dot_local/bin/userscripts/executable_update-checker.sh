#!/bin/bash

# Script to check for available updates and optionally run update-local --quick

# Get updates from pacman (checkupdates)
pacman_updates=$(checkupdates 2>/dev/null)
pacman_exit_code=$?

# Get updates from AUR (yay -Qua)
if command -v yay &> /dev/null; then
    yay_updates=$(yay -Qua 2>/dev/null)
    yay_exit_code=$?
else
    yay_updates=""
    yay_exit_code=1
fi

# Check if there are any updates
has_pacman_updates=false
has_yay_updates=false

if [ $pacman_exit_code -eq 0 ] && [ -n "$pacman_updates" ]; then
    has_pacman_updates=true
fi

if [ $yay_exit_code -eq 0 ] && [ -n "$yay_updates" ]; then
    has_yay_updates=true
fi

# Display available updates
if [ "$has_pacman_updates" = true ] || [ "$has_yay_updates" = true ]; then
    echo "======================================"
    echo "   Available Updates"
    echo "======================================"
    echo ""
    
    if [ "$has_pacman_updates" = true ]; then
        echo "📦 Pacman (official repos):"
        echo "$pacman_updates" | while read -r line; do
            echo "   $line"
        done
        echo ""
    fi
    
    if [ "$has_yay_updates" = true ]; then
        echo "🎨 AUR (yay):"
        echo "$yay_updates" | while read -r line; do
            echo "   $line"
        done
        echo ""
    fi
    
    echo "======================================"
    echo ""
    
    # Ask user if they want to update
    read -r -p "Do you want to run 'update-local --quick'? [y/N] " response
    
    # Default is N, so anything other than Y or y means no
    case "$response" in
        [Yy])
            echo ""
            echo "Running update-local --quick..."
            update-local --quick
            ;;
        *)
            echo "Update cancelled."
            exit 0
            ;;
    esac
else
    echo "✅ No updates available!"
    exit 0
fi
