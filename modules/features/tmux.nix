{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.tmux = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = [ self'.packages.myTmux ];
    }
  );

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.myTmux = inputs.wrapper-modules.wrappers.tmux.wrap {
        inherit pkgs;

        prefix = "C-a";
        mouse = true;
        escapeTime = 10;
        terminal = "screen-256color";
        terminalOverrides = ",xterm-256color:RGB";
        statusKeys = "vi";
        modeKeys = "vi";
        visualActivity = false;

        sourceSensible = true;
        plugins = [
          { plugin = pkgs.tmuxPlugins.yank; }
        ];

        configBefore = ''
          set-window-option -g automatic-rename on
          set-option -g set-titles on

          set -g focus-events on
          set -g status-interval 1

          set -g visual-bell off
          set -g visual-silence off
          setw -g monitor-activity off
          set -g bell-action none
        '';

        configAfter = ''
          # split panes using | and -
          bind < split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
          bind , copy-mode
          bind . paste-buffer
          bind c new-window -c "#{pane_current_path}"
          bind a set-window-option synchronize-panes
          unbind '"'
          unbind %

          # Smart pane switching with awareness of Vim splits.
          # See: https://github.com/christoomey/vim-tmux-navigator
          is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
              | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(di)?$'"
          bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
          bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
          bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
          bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
          bind-key -n 'C-\' if-shell "$is_vim" 'send-keys C-\\'  'select-pane -l'

          bind-key -T copy-mode-vi 'C-h' select-pane -L
          bind-key -T copy-mode-vi 'C-j' select-pane -D
          bind-key -T copy-mode-vi 'C-k' select-pane -U
          bind-key -T copy-mode-vi 'C-l' select-pane -R
          bind-key -T copy-mode-vi 'C-\' select-pane -l

          # Use shift + arrow key to move between windows in a session
          bind -n S-Left  previous-window
          bind -n S-Right next-window

          # Prefix + / to search
          bind-key / copy-mode \; send-key ?

          # Setup 'v' to begin selection, just like Vim
          # ('y' to copy is handled by the tmux-yank plugin, which picks
          # wl-copy/xclip/pbcopy automatically depending on the platform)
          bind-key -T copy-mode-vi 'v' send -X begin-selection
          bind-key -T copy-mode-vi 'V' send -X select-line
          bind-key -T copy-mode-vi 'r' send -X rectangle-toggle

          # config is managed by Nix; edit modules/features/tmux.nix and rebuild instead
          bind r display-message "tmux config is managed by Nix -- edit modules/features/tmux.nix"

          ######################
          ### DESIGN CHANGES ###
          ######################

          # modes
          setw -g clock-mode-colour colour5
          setw -g mode-style 'fg=colour1 bg=#282828 bold'

          # panes
          set -g pane-border-style 'fg=#383838 bg=colour0'
          set -g pane-active-border-style 'bg=colour0 fg=colour9'

          # statusbar
          set -g status-position bottom
          set -g status-justify left
          set -g status-style 'bg=#282828 fg=colour137 dim'
          set -g status-left '''
          set -g status-right '''
          set -g status-left-length 20

          setw -g window-status-current-style 'fg=colour1 bg=#383838 bold'
          setw -g window-status-current-format ' #I#[fg=colour249]:#[fg=colour255]#W#[fg=colour249]#F '

          setw -g window-status-style 'fg=colour9 bg=#282828'
          setw -g window-status-format ' #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F '

          setw -g window-status-bell-style 'fg=colour255 bg=colour1 bold'

          # messages
          set -g message-style 'fg=colour232 bg=#dc9656 bold'
        '';
      };
    };
}
