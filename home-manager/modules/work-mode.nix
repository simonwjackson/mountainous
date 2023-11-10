{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.work-mode;
  package = pkgs.work-mode;
  popup-term = "${pkgs.popup-term}/bin/popup-term";
in {
  options.programs.work-mode = {
    enable = lib.mkEnableOption "work-mode";

    monitor = lib.mkOption {
      default = "eDP-1";
      type = lib.types.str;
      description = ''
        Main monitor
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # programs.mbsync.enable = true;
    # programs.notmuch.enable = true;
    #
    # accounts.email = {
    #   maildirBasePath = "/glacier/snowscape/email";
    #   accounts = {
    #     "gmail" = {
    #       primary = true;
    #       address = "simon.jackson@gmail.com";
    #       userName = "simon.jackson@gmail.com";
    #       realName = "Simon W. Jackson";
    #       passwordCommand = "echo 'ahxt gqzc afnj xmfr'";
    #       imap.host = "imap.gmail.com";
    #       smtp.host = "smtp.gmail.com";
    #       mbsync = {
    #         enable = true;
    #         create = "both";
    #         expunge = "both";
    #         patterns = ["*" "![Gmail]*" "[Gmail]/Sent Mail" "[Gmail]/Starred" "[Gmail]/All Mail"];
    #         extraConfig = {
    #           channel = {
    #             Sync = "All";
    #           };
    #           account = {
    #             Timeout = 120;
    #             PipelineDepth = 1;
    #           };
    #         };
    #       };
    #       notmuch.enable = true;
    #       msmtp.enable = true;
    #     };
    #   };
    # };

    gtk = {
      enable = true;
      # iconTheme = {
      #   name = "xfce4-icon-theme";
      #   package = pkgs.xfce.xfce4-icon-theme;
      # };
      theme = {
        name = "matcha-dark-sea";
        package = pkgs.matcha-gtk-theme;
      };
      gtk3.extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
      gtk4.extraConfig = {
        Settings = ''
          gtk-application-prefer-dark-theme=1
        '';
      };
    };

    xsession = {
      enable = true;
      scriptPath = ".hm-xsession";
      windowManager.bspwm = {
        rules = {
          "focused-menu" = {
            state = "floating";
            rectangle = "800x1000+0+0";
            center = true;
            focus = true;
          };
        };
        enable = true;
        startupPrograms = [
          "xsetroot -solid black"
          "pgrep -f 'main-term' > /dev/null || kitty --class main-term"
          "pgrep firefox || firefox"
        ];
        extraConfig = ''
          bspc subscribe all > ~/bspc-report.log &
        '';
        monitors = {
          "${cfg.monitor}" = ["dev"];
          # "${cfg.monitor}" = ["dev" "games"];
        };
        settings = let
          padding = 25;
        in {
          bottom_padding = -padding;
          window_gap = padding;
          split_ratio = 0.618;
          focus_follows_pointer = true;
          borderless_monocle = true;
          # history_aware_focus    true
        };
      };
      # Configurations when hotplugging monitors
      # bspc config remove_disabled_monitors true
      # bspc config remove_unplugged_monitors true
      # bspc config merge_overlapping_monitors true;
      # bspc rule -a firefox state=tiled
      # windowManager.command = lib.mkForce ''
      #   exec ${pkgs.bspwm}/bin/bspwm -c /home/simonwjackson/.config/bspwm/bspwmrc
      # '';
    };

    home.file.".config/picom/config" = {
      text = ''
        #################################
        #          Animations           #
        #################################
        # requires https://github.com/jonaburg/picom
        # (These are also the default values)
        transition-length = 300
        transition-pow-x = 0.1
        transition-pow-y = 0.1
        transition-pow-w = 0.1
        transition-pow-h = 0.1
        size-transition = true


        #################################
        #             Corners           #
        #################################
        # requires: https://github.com/sdhand/compton or https://github.com/jonaburg/picom
        corner-radius = 3;
        rounded-corners-exclude = [
          #"window_type = 'normal'",
          "class_g = 'awesome'",
          "class_g = 'URxvt'",
          "class_g = 'XTerm'",
          "class_g = 'kitty'",
          "class_g = 'Alacritty'",
          "class_g = 'Polybar'",
          "class_g = 'code-oss'",
          #"class_g = 'TelegramDesktop'",
          "class_g = 'firefox'",
          "class_g = 'Thunderbird'"
        ];
        round-borders = 1;
        round-borders-exclude = [
          #"class_g = 'TelegramDesktop'",
        ];

        #################################
        #             Shadows           #
        #################################


        # Enabled client-side shadows on windows. Note desktop windows
        # (windows with '_NET_WM_WINDOW_TYPE_DESKTOP') never get shadow,
        # unless explicitly requested using the wintypes option.
        #
        # shadow = false
        shadow = true;

        # The blur radius for shadows, in pixels. (defaults to 12)
        # shadow-radius = 12
        shadow-radius = 30;

        # The opacity of shadows. (0.0 - 1.0, defaults to 0.75)
        shadow-opacity = .30

        # The left offset for shadows, in pixels. (defaults to -15)
        # shadow-offset-x = -15
        shadow-offset-x = -30;

        # The top offset for shadows, in pixels. (defaults to -15)
        # shadow-offset-y = -15
        shadow-offset-y = -30;

        # Avoid drawing shadows on dock/panel windows. This option is deprecated,
        # you should use the *wintypes* option in your config file instead.
        #
        # no-dock-shadow = false

        # Don't draw shadows on drag-and-drop windows. This option is deprecated,
        # you should use the *wintypes* option in your config file instead.
        #
        # no-dnd-shadow = false

        # Red color value of shadow (0.0 - 1.0, defaults to 0).
        # shadow-red = 0

        # Green color value of shadow (0.0 - 1.0, defaults to 0).
        # shadow-green = 0

        # Blue color value of shadow (0.0 - 1.0, defaults to 0).
        # shadow-blue = 0

        # Do not paint shadows on shaped windows. Note shaped windows
        # here means windows setting its shape through X Shape extension.
        # Those using ARGB background is beyond our control.
        # Deprecated, use
        #   shadow-exclude = 'bounding_shaped'
        # or
        #   shadow-exclude = 'bounding_shaped && !rounded_corners'
        # instead.
        #
        # shadow-ignore-shaped = ""

        # Specify a list of conditions of windows that should have no shadow.
        #
        # examples:
        #   shadow-exclude = "n:e:Notification";
        #
        # shadow-exclude = []
        shadow-exclude = [
          "name = 'Notification'",
          "class_g = 'Conky'",
          "class_g ?= 'Notify-osd'",
          "class_g = 'Cairo-clock'",
          "class_g = 'slop'",
          "class_g = 'Polybar'",
          "_GTK_FRAME_EXTENTS@:c"
        ];

        # Specify a X geometry that describes the region in which shadow should not
        # be painted in, such as a dock window region. Use
        #    shadow-exclude-reg = "x10+0+0"
        # for example, if the 10 pixels on the bottom of the screen should not have shadows painted on.
        #
        # shadow-exclude-reg = ""

        # Crop shadow of a window fully on a particular Xinerama screen to the screen.
        # xinerama-shadow-crop = false


        #################################
        #           Fading              #
        #################################


        # Fade windows in/out when opening/closing and when opacity changes,
        #  unless no-fading-openclose is used.
        # fading = false
        fading = true;

        # Opacity change between steps while fading in. (0.01 - 1.0, defaults to 0.028)
        # fade-in-step = 0.028
        fade-in-step = 0.03;

        # Opacity change between steps while fading out. (0.01 - 1.0, defaults to 0.03)
        # fade-out-step = 0.03
        fade-out-step = 0.03;

        # The time between steps in fade step, in milliseconds. (> 0, defaults to 10)
        # fade-delta = 10

        # Specify a list of conditions of windows that should not be faded.
        # don't need this, we disable fading for all normal windows with wintypes: {}
        fade-exclude = [
          "class_g = 'slop'"   # maim
        ]

        # Do not fade on window open/close.
        # no-fading-openclose = false

        # Do not fade destroyed ARGB windows with WM frame. Workaround of bugs in Openbox, Fluxbox, etc.
        # no-fading-destroyed-argb = false


        #################################
        #   Transparency / Opacity      #
        #################################


        # Opacity of inactive windows. (0.1 - 1.0, defaults to 1.0)
        # inactive-opacity = 1
        inactive-opacity = 1;

        # Opacity of window titlebars and borders. (0.1 - 1.0, disabled by default)
        # frame-opacity = 1.0
        #frame-opacity = 0.7;

        # Default opacity for dropdown menus and popup menus. (0.0 - 1.0, defaults to 1.0)
        # menu-opacity = 1.0
        # menu-opacity is depreciated use dropdown-menu and popup-menu instead.

        #If using these 2 below change their values in line 510 & 511 aswell
        popup_menu = { opacity = 0.8; }
        dropdown_menu = { opacity = 0.8; }


        # Let inactive opacity set by -i override the '_NET_WM_OPACITY' values of windows.
        # inactive-opacity-override = true
        inactive-opacity-override = false;

        # Default opacity for active windows. (0.0 - 1.0, defaults to 1.0)
        active-opacity = 1.0;

        # Dim inactive windows. (0.0 - 1.0, defaults to 0.0)
        # inactive-dim = 0.0

        # Specify a list of conditions of windows that should always be considered focused.
        # focus-exclude = []
        focus-exclude = [
          "class_g = 'Cairo-clock'",
          "class_g = 'Bar'",                    # lemonbar
          "class_g = 'slop'"                    # maim
        ];

        # Use fixed inactive dim value, instead of adjusting according to window opacity.
        # inactive-dim-fixed = 1.0

        # Specify a list of opacity rules, in the format `PERCENT:PATTERN`,
        # like `50:name *= "Firefox"`. picom-trans is recommended over this.
        # Note we don't make any guarantee about possible conflicts with other
        # programs that set '_NET_WM_WINDOW_OPACITY' on frame or client windows.
        # example:
        #    opacity-rule = [ "80:class_g = 'URxvt'" ];
        #
        # opacity-rule = []
        opacity-rule = [
          "80:class_g     = 'Bar'",             # lemonbar
          "100:class_g    = 'slop'",            # maim
          "100:class_g    = 'XTerm'",
          "100:class_g    = 'URxvt'",
          "100:class_g    = 'kitty'",
          "100:class_g    = 'Alacritty'",
          "80:class_g     = 'Polybar'",
          "100:class_g    = 'code-oss'",
          "100:class_g    = 'Meld'",
          "100:class_g     = 'TelegramDesktop'",
          "90:class_g     = 'Joplin'",
          "100:class_g    = 'firefox'",
          "100:class_g    = 'Thunderbird'",
          "100:class_g    = 'resolve'"
        ];


        #################################
        #     Background-Blurring       #
        #################################


        # Parameters for background blurring, see the *BLUR* section for more information.
        # blur-method =
        # blur-size = 12
        #
        # blur-deviation = false

        # Blur background of semi-transparent / ARGB windows.
        # Bad in performance, with driver-dependent behavior.
        # The name of the switch may change without prior notifications.
        #
        # blur-background = true;

        # Blur background of windows when the window frame is not opaque.
        # Implies:
        #    blur-background
        # Bad in performance, with driver-dependent behavior. The name may change.
        #
        # blur-background-frame = false;


        # Use fixed blur strength rather than adjusting according to window opacity.
        # blur-background-fixed = false;


        # Specify the blur convolution kernel, with the following format:
        # example:
        #   blur-kern = "5,5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1";
        #
        # blur-kern = ""
        # blur-kern = "3x3box";

        blur: {
          # requires: https://github.com/ibhagwan/picom
          method = "kawase";
          #method = "kernel";
          strength = 5;
          # deviation = 1.0;
          # kernel = "11x11gaussian";
          background = false;
          background-frame = false;
          background-fixed = false;
          kern = "3x3box";
        }

        # Exclude conditions for background blur.
        blur-background-exclude = [
          "window_type = 'dock'",
          #"window_type = 'desktop'",
          #"class_g = 'URxvt'",
          "class_g = 'Color Picker'",
          #
          # prevents picom from blurring the background
          # when taking selection screenshot with `main`
          # https://github.com/naelstrof/maim/issues/130
          "class_g = 'slop'",
          "_GTK_FRAME_EXTENTS@:c"
        ];


        #################################
        #       General Settings        #
        #################################

        # Daemonize process. Fork to background after initialization. Causes issues with certain (badly-written) drivers.
        # daemon = false

        # Specify the backend to use: `xrender`, `glx`, or `xr_glx_hybrid`.
        # `xrender` is the default one.
        #
        experimental-backends = true;
        backend = "glx";
        #backend = "xrender";


        # Enable/disable VSync.
        # vsync = false
        vsync = false

        # Enable remote control via D-Bus. See the *D-BUS API* section below for more details.
        # dbus = false

        # Try to detect WM windows (a non-override-redirect window with no
        # child that has 'WM_STATE') and mark them as active.
        #
        # mark-wmwin-focused = false
        mark-wmwin-focused = true;

        # Mark override-redirect windows that doesn't have a child window with 'WM_STATE' focused.
        # mark-ovredir-focused = false
        mark-ovredir-focused = true;

        # Try to detect windows with rounded corners and don't consider them
        # shaped windows. The accuracy is not very high, unfortunately.
        #
        # detect-rounded-corners = false
        detect-rounded-corners = true;

        # Detect '_NET_WM_OPACITY' on client windows, useful for window managers
        # not passing '_NET_WM_OPACITY' of client windows to frame windows.
        #
        # detect-client-opacity = false
        detect-client-opacity = true;

        # Specify refresh rate of the screen. If not specified or 0, picom will
        # try detecting this with X RandR extension.
        #
        # refresh-rate = 60
        refresh-rate = 60

        # Limit picom to repaint at most once every 1 / 'refresh_rate' second to
        # boost performance. This should not be used with
        #   vsync drm/opengl/opengl-oml
        # as they essentially does sw-opti's job already,
        # unless you wish to specify a lower refresh rate than the actual value.
        #
        # sw-opti =

        # Use EWMH '_NET_ACTIVE_WINDOW' to determine currently focused window,
        # rather than listening to 'FocusIn'/'FocusOut' event. Might have more accuracy,
        # provided that the WM supports it.
        #
        # use-ewmh-active-win = false

        # Unredirect all windows if a full-screen opaque window is detected,
        # to maximize performance for full-screen windows. Known to cause flickering
        # when redirecting/unredirecting windows. paint-on-overlay may make the flickering less obvious.
        #
        # unredir-if-possible = false

        # Delay before unredirecting the window, in milliseconds. Defaults to 0.
        # unredir-if-possible-delay = 0

        # Conditions of windows that shouldn't be considered full-screen for unredirecting screen.
        # unredir-if-possible-exclude = []

        # Use 'WM_TRANSIENT_FOR' to group windows, and consider windows
        # in the same group focused at the same time.
        #
        # detect-transient = false
        detect-transient = true

        # Use 'WM_CLIENT_LEADER' to group windows, and consider windows in the same
        # group focused at the same time. 'WM_TRANSIENT_FOR' has higher priority if
        # detect-transient is enabled, too.
        #
        # detect-client-leader = false
        detect-client-leader = true

        # Resize damaged region by a specific number of pixels.
        # A positive value enlarges it while a negative one shrinks it.
        # If the value is positive, those additional pixels will not be actually painted
        # to screen, only used in blur calculation, and such. (Due to technical limitations,
        # with use-damage, those pixels will still be incorrectly painted to screen.)
        # Primarily used to fix the line corruption issues of blur,
        # in which case you should use the blur radius value here
        # (e.g. with a 3x3 kernel, you should use `--resize-damage 1`,
        # with a 5x5 one you use `--resize-damage 2`, and so on).
        # May or may not work with *--glx-no-stencil*. Shrinking doesn't function correctly.
        #
        # resize-damage = 1

        # Specify a list of conditions of windows that should be painted with inverted color.
        # Resource-hogging, and is not well tested.
        #
        # invert-color-include = []

        # GLX backend: Avoid using stencil buffer, useful if you don't have a stencil buffer.
        # Might cause incorrect opacity when rendering transparent content (but never
        # practically happened) and may not work with blur-background.
        # My tests show a 15% performance boost. Recommended.
        #
        # glx-no-stencil = false

        # GLX backend: Avoid rebinding pixmap on window damage.
        # Probably could improve performance on rapid window content changes,
        # but is known to break things on some drivers (LLVMpipe, xf86-video-intel, etc.).
        # Recommended if it works.
        #
        # glx-no-rebind-pixmap = false

        # Disable the use of damage information.
        # This cause the whole screen to be redrawn everytime, instead of the part of the screen
        # has actually changed. Potentially degrades the performance, but might fix some artifacts.
        # The opposing option is use-damage
        #
        # no-use-damage = false
        #use-damage = true (Causing Weird Black semi opaque rectangles when terminal is opened)
        #Changing use-damage to false fixes the problem
        use-damage = false

        # Use X Sync fence to sync clients' draw calls, to make sure all draw
        # calls are finished before picom starts drawing. Needed on nvidia-drivers
        # with GLX backend for some users.
        #
        # xrender-sync-fence = false

        # GLX backend: Use specified GLSL fragment shader for rendering window contents.
        # See `compton-default-fshader-win.glsl` and `compton-fake-transparency-fshader-win.glsl`
        # in the source tree for examples.
        #
        # glx-fshader-win = ""

        # Force all windows to be painted with blending. Useful if you
        # have a glx-fshader-win that could turn opaque pixels transparent.
        #
        # force-win-blend = false

        # Do not use EWMH to detect fullscreen windows.
        # Reverts to checking if a window is fullscreen based only on its size and coordinates.
        #
        # no-ewmh-fullscreen = false

        # Dimming bright windows so their brightness doesn't exceed this set value.
        # Brightness of a window is estimated by averaging all pixels in the window,
        # so this could comes with a performance hit.
        # Setting this to 1.0 disables this behaviour. Requires --use-damage to be disabled. (default: 1.0)
        #
        # max-brightness = 1.0

        # Make transparent windows clip other windows like non-transparent windows do,
        # instead of blending on top of them.
        #
        # transparent-clipping = false

        # Set the log level. Possible values are:
        #  "trace", "debug", "info", "warn", "error"
        # in increasing level of importance. Case doesn't matter.
        # If using the "TRACE" log level, it's better to log into a file
        # using *--log-file*, since it can generate a huge stream of logs.
        #
        # log-level = "debug"
        log-level = "info";

        # Set the log file.
        # If *--log-file* is never specified, logs will be written to stderr.
        # Otherwise, logs will to written to the given file, though some of the early
        # logs might still be written to the stderr.
        # When setting this option from the config file, it is recommended to use an absolute path.
        #
        # log-file = '/path/to/your/log/file'

        # Show all X errors (for debugging)
        # show-all-xerrors = false

        # Write process ID to a file.
        # write-pid-path = '/path/to/your/log/file'

        # Window type settings
        #
        # 'WINDOW_TYPE' is one of the 15 window types defined in EWMH standard:
        #     "unknown", "desktop", "dock", "toolbar", "menu", "utility",
        #     "splash", "dialog", "normal", "dropdown_menu", "popup_menu",
        #     "tooltip", "notification", "combo", and "dnd".
        #
        # Following per window-type options are available: ::
        #
        #   fade, shadow:::
        #     Controls window-type-specific shadow and fade settings.
        #
        #   opacity:::
        #     Controls default opacity of the window type.
        #
        #   focus:::
        #     Controls whether the window of this type is to be always considered focused.
        #     (By default, all window types except "normal" and "dialog" has this on.)
        #
        #   full-shadow:::
        #     Controls whether shadow is drawn under the parts of the window that you
        #     normally won't be able to see. Useful when the window has parts of it
        #     transparent, and you want shadows in those areas.
        #
        #   redir-ignore:::
        #     Controls whether this type of windows should cause screen to become
        #     redirected again after been unredirected. If you have unredir-if-possible
        #     set, and doesn't want certain window to cause unnecessary screen redirection,
        #     you can set this to `true`.
        #
        wintypes:
        {
          normal = { fade = false; shadow = true; }
          tooltip = { fade = true; shadow = true; opacity = 0.75; focus = true; full-shadow = false; };
          dock = { shadow = false; }
          dnd = { shadow = false; }
          popup_menu = { opacity = 0.8; }
          dropdown_menu = { opacity = 0.8; }
        };
      '';
    };

    systemd.user.services.picom.serviceConfig.ExecStart = [
      "" # First element as empty string to override the previous command
      "${pkgs.picom}/bin/picom --config /home/simonwjackson/.config/picom/config"
    ];

    services.picom = {
      enable = false;
      # activeOpacity = "0.90";
      # blur = true;
      # blurExclude = [
      #   "class_g = 'slop'"
      # ];
      # extraOptions = '' '';

      # shadowExclude = [
      #   "bounding_shaped && !rounded_corners"
      # ];

      # fade = true;
      # kfadeDelta = 5;
      # vSync = true;
      # opacityRule = [
      #   "100:class_g   *?= 'Chromium-browser'"
      #   "100:class_g   *?= 'Firefox'"
      #   "100:class_g   *?= 'gitkraken'"
      #   "100:class_g   *?= 'emacs'"
      #   "100:class_g   ~=  'jetbrains'"
      #   "100:class_g   *?= 'slack'"
      # ];
      package = pkgs.picom.overrideAttrs (o: {
        src = pkgs.fetchFromGitHub {
          repo = "picom";
          owner = "jonaburg";
          rev = "e3c19cd7d1108d114552267f302548c113278d45";
          sha256 = "4voCAYd0fzJHQjJo4x3RoWz5l3JJbRvgIXn1Kg6nz6Y=";
        };
      });
    };

    # home.activation = {
    #   reloadDesktop = let
    #     pgrep = "${pkgs.procps}/bin/pgrep";
    #     bspc = "${pkgs.bspwm}/bin/bspc";
    #     sxhkd = "${pkgs.sxhkd}/bin/sxhkd";
    #     killall = "${pkgs.killall}/bin/killall";
    #   in
    #     lib.hm.dag.entryAfter ["writeBoundary"] ''
    #       ${pgrep} bspwm > /dev/null && ${bspc} wm --restart &
    #       ${pgrep} sxhkd > /dev/null && ${killall} sxhkd; ${sxhkd} &
    #     '';
    # };

    services.sxhkd = {
      enable = true;
      keybindings = let
        max-toggle = "${pkgs.herbstluftwm-scripts}/bin/herb-max-toggle";
        kitty = "${pkgs.kitty}/bin/kitty";
        nmtui = "${pkgs.networkmanager}/bin/nmtui";
        # term-popup = "${popup} ${kitty} --";
        layout = "${pkgs.bsp-layout}/bin/bsp-layout";
        bspc = "${pkgs.bspwm}/bin/bspc";
        brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
        wmctrl = "${pkgs.wmctrl}/bin/wmctrl";
        pamixer = "${pkgs.pamixer}/bin/pamixer";
        bspwm-toggle-visibility = let
          xdo = "${pkgs.xdo}/bin/xdo";
          head = "${pkgs.coreutils}/bin/head";
          cut = "${pkgs.coreutils}/bin/cut";
          bspc = "${pkgs.bspwm}/bin/bspc";
          jq = "${pkgs.jq}/bin/jq";
        in
          (pkgs.writeShellScriptBin "bspwm-toggle-visibility" ''
            if [ $# = 0 ]; then
                cat <<EOF
            Usage: $(basename "$0") process_name [executable_name] [--take-first]
                process_name       As recognized by 'xdo' command
                executable_name    As used for launching from terminal
                --take-first       In case 'xdo' returns multiple process IDs
            EOF
                exit 0
            fi

            # Get id of process by class name and then fallback to instance name
            id=$(${xdo} id -N "$1" || ${xdo} id -n "$1")

            executable=$1
            shift

            while [ -n "$1" ]; do
                case $1 in
                --take-first)
                    id=$(${head} -1 <<<"$id" | ${cut} -f1 -d' ')
                    ;;
                *)
                    executable=$1
                    ;;
                esac
                shift
            done

            if [ -z "$id" ]; then
                $executable
            else
                while read -r instance; do
                    ${bspc} node "$instance" --flag hidden --to-monitor focused --focus
                done <<<"$id"
            fi
          '')
          + "/bin/bspwm-toggle-visibility";
        resize-script =
          (pkgs.writeShellScriptBin "resize-script" ''
            direction=$1

            if [ "" = "$direction" ]; then
              echo "No direction given"
              exit 1
            fi

            if [ "$direction" = "west" ]; then
              ${bspc} node -z left -20 0 || ${bspc} node -z right -20 0
            elif [ "$direction" = "south" ]; then
              ${bspc} node -z bottom 0 20 || ${bspc} node -z top 0 20
            elif [ "$direction" = "north" ]; then
              ${bspc} node -z top 0 -20 || ${bspc} node -z bottom 0 -20
            elif [ "$direction" = "east" ]; then
              ${bspc} node -z right 20 0 || ${bspc} node -z left 20 0
            fi
          '')
          + "/bin/resize-script";
        bsp-layout = let
          bc = "${pkgs.bc}/bin/bc";
        in
          (pkgs.writeShellScriptBin "bsp-layout" ''
            PATH="${pkgs.bc}/bin:$PATH" ${pkgs.bsp-layout}/bin/bsp-layout $@
          '')
          + "/bin/bsp-layout";
      in {
        "super + space" = ''
          ${popup-term} ${pkgs.wifi-select}/bin/wifi-select
        '';
        "super + m" = ''
          ${bsp-layout} next --layouts rtall,monocle
        '';
        "super + {_, shift} + Tab" = ''
          ${bspc} node -f '{next,prev}.!hidden.window.local'
        '';
        "super + Return" = ''
          ${kitty}
        '';
        "XF86Audio{Raise,Lower}Volume" = ''
          ${pamixer} --{increase,decrease} 5
        '';
        "super + t" = ''
          ${wmctrl} -xa main-term || kitty --class main-term
        '';
        "super + w" = ''
          ${wmctrl} -xa $BROWSER || $BROWSER
        '';
        "{XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
          ${brightnessctl} --device='*' --exponent set 5%{-,+}
        '';
        "super + {XF86MonBrightnessDown,XF86MonBrightnessUp}" = ''
          ${brightnessctl} --device='*' set {1,100}%
        '';
        "super + {Left,Down,Up,Right}" = ''
          ${resize-script} {west,south,north,east}
        '';
        "super + {h,j,k,l}" = ''
          ${bspc} node --focus {west,south,north,east}
        '';
        "super + shift + {h,j,k,l}" = ''
          ${bspc} node @/ -C {forward,backward,forward,backward}
        '';
        # "super + ctrl + {h,j,k,l}" = ''
        #   ${hc} split {left,bottom,top,right} 0.382
        # '';
        "super + {4}" = ''
          ${bspc} desktop --focus {dev}
        '';
        "super + shift + {4}" = ''
          ${bspc} node --to-desktop {dev} --follow
        '';

        "super + button2" = ''
          ${bspc} node --state '~floating'
        '';
        "super + r" = ''
          ${bspc} wm --restart
        '';
      };
    };

    fonts.fontconfig.enable = true;
    home.packages = [
      pkgs."material-icons"
      (pkgs.nerdfonts.override {
        fonts = [
          "Noto"
          "BitstreamVeraSansMono"
          # "Droid"
          "Iosevka"
          "FantasqueSansMono"
          "DroidSansMono"
          "Terminus"
        ];
      })
    ];

    services.polybar = {
      enable = true;
      # package = inputs.nixpkgs-unstable.polybar.override {
      #   alsaSupport = true;
      #   pulseSupport = true;
      # };
      script = "polybar top &";
      settings = let
        icons = {
          vpn = {
            active = "";
            inactive = "";
          };
          rotate = "";
          cpu = "";
          memory = "";
          date = "";
          microphone = "";
          microphone-muted = "";
          microphone-disconnected = "";
          wifi = "";
          up = "";
          down = "";
          ethernet = "";
          envelope = "";
        };

        background = "#99000000";
        background-alt = "#99000000";

        foreground = "#ffdddddd";
        foreground-alt = "#ffdddddd";

        primary = "#ff006633";
        secondary = "#ff003333";
        alert = "#ff330000";
        fonts = {
          font = [
            "DroidSansM Nerd Font Mono:style=Regular:pixelsize=12:antialias=true;0"
            # "NotoSansM Nerd Font Mono:antialias=true"
          ];
        };
      in {
        "bar/top" =
          fonts
          // {
            monitor = "\${env:MONITOR:${cfg.monitor}}";
            width = "100%";
            height = 20;
            offset-y = 26;
            # offset-x = 25;
            radius = 0;
            module-margin = 1;
            modules = {
              left = "empty-module bspwm xwindow";
              center = "time";
              right = "cpu-profile rotate tailscale battery wlan empty-module";
            };
            # offset.y = 30;
          };

        "module/bspwm" = {
          type = "internal/bspwm";

          # Use FontAwesome or Nerd Fonts for icons
          label-focused = "%{F#ffffff}%{A1:bspc desktop -f %index%:}%icon%%{A}%{F-}";
          label-occupied = "%{F#555}%{A1:bspc desktop -f %index%:}%icon%%{A}%{F-}";
          label-urgent = "%{F#ff0000}%{A1:bspc desktop -f %index%:}%icon%%{A}%{F-}";
          label-empty = "%{F#555555}%{A1:bspc desktop -f %index%:}%icon%%{A}%{F-}";

          ws-icon = [
            "dev;"
            "games;󰸳"
          ];

          label-separator = "|";
          label-separator-padding = 0;
          label-separator-foreground = "#000000";

          # Only show workspaces defined on the same output as the bar
          # NOTE: The bspwm and XRandR monitor names must match, which they do by default.
          # But if you rename your bspwm monitors with bspc -n this option will no longer
          # behave correctly.
          # Default: true
          pin-workspaces = true;

          # Output mode flags after focused state label
          # Default: false
          inline-mode = false;

          # Create click handler used to focus workspace
          # Default: true
          enable-click = true;

          # Create scroll handlers used to cycle workspaces
          # Default: true
          enable-scroll = false;

          # Use fuzzy (partial) matching on labels when assigning
          # icons to workspaces
          # Example: code;♚ will apply the icon to all workspaces
          # containing 'code' in the label
          # Default: false
          fuzzy-match = true;
        };

        "module/empty-module" = {
          type = "custom/text";
          content = " ";
          width = 25;
        };

        "module/xwindow" = {
          type = "internal/xwindow";
          label = "%title:0:30:...%";
        };

        "module/wlan" = {
          type = "internal/network";
          interval = "3.0";
          interface.type = "wireless";

          format-connected = "%{A1:${popup-term} ${pkgs.wifi-select}/bin/wifi-select:}<ramp-signal> <label-connected>%{A}";
          label-connected = "%essid%";

          ramp = {
            signal = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            signal-foreground = foreground-alt;
          };
        };

        "module/battery" = {
          type = "internal/battery";
          battery = "BAT1";
          adapter = "ADP1";
          full-at = "98";

          format.charging = "<ramp-capacity> <label-discharging>";
          format.discharging = "<ramp-capacity> <label-discharging>";
          format.full-prefix = " ";
          format-full-prefix-foreground = foreground;

          ramp.capacity = ["" "" ""];
          ramp-capacity-foreground = foreground;
        };

        # "module/notmuch" = {
        #   type = "custom/script";
        #   exec = "echo -n '${icons.envelope} '; ${pkgs.notmuch}/bin/notmuch search tag:unread | wc -l";
        #   tail = true;
        #   interval = 10;
        #   click-left = "${pkgs.astroid}/bin/astroid";
        # };

        "module/cpu-profile" = let
          cpu-profile = "${pkgs.cpu-profile}/bin/cpu-profile";
        in {
          type = "custom/script";
          exec =
            (pkgs.writeShellScriptBin "cpu-profile-polybar-exec" ''
              profile="$(${cpu-profile} get)"

              if [ "$profile" = "performance" ]; then
                echo "󱩡"
              elif [ "$profile" = "powersave" ]; then
                echo "󰳗"
              fi
            '')
            + "/bin/cpu-profile-polybar-exec";
          tail = true;
          interval = 10;
          click-left = "sudo ${cpu-profile} cycle";
        };

        "module/tailscale" = {
          type = "custom/script";
          exec =
            # TODO: Move to own script file
            # TODO: Left click toggles VPN
            # TODO: right click toggles exitnode off / popup
            let
              curl = "${pkgs.curl}/bin/curl";
              jq = "${pkgs.jq}/bin/jq";
            in
              (pkgs.writeShellScriptBin "tailscale-check" ''
                ICON_ACTIVE="${icons.vpn.active}"
                ICON_INACTIVE="${icons.vpn.inactive}"

                status=$(${curl} --silent --fail --unix-socket /var/run/tailscale/tailscaled.sock http://local-tailscaled.sock/localapi/v0/status)

                # bail out if curl had non-zero exit code
                if [ $? != 0 ]; then
                    exit 0
                fi

                # check if it's stopped (down)
                if [ "$(echo $status | ${jq} --raw-output .BackendState)" = "Stopped" ]; then
                    echo "$ICON_INACTIVE !!! VPN DOWN !!!"
                    exit 0
                fi

                # if an exit node is active, show its hostname
                exit_node_hostname="$(echo $status | ${jq} --raw-output '.Peer[] | select(.ExitNode) | .HostName')"
                if [ -n "$exit_node_hostname" ]; then
                    echo "$ICON_ACTIVE $exit_node_hostname"
                else
                    echo "$ICON_ACTIVE"
                fi
              '')
              + "/bin/tailscale-check";
          tail = true;
          interval = 2;
        };

        "module/rotate" = {
          type = "custom/text";
          content = "${icons.rotate}";
          click-left = let
            xrandr = "${pkgs.xorg.xrandr}/bin/xrandr";
            xinput = "${pkgs.xorg.xinput}/bin/xinput";
            grep = "${pkgs.gnugrep}/bin/grep";
            awk = "${pkgs.gawk}/bin/awk";
          in
            (pkgs.writeShellScriptBin "invert-screen" ''
              rotation=$(${xrandr} --query --verbose | ${grep} '${cfg.monitor} connected primary' | ${awk} '{print $6}')
              screen="${cfg.monitor}"
              device="GXTP7936:00 27C6:0123"

              # Rotate screen and touchscreen input based on the current state
              if [ "$rotation" == "inverted" ]; then
                ${xrandr} --output "$screen" --rotate normal
                ${xinput} set-prop "$device" 'Coordinate Transformation Matrix' 1 0 0 0 1 0 0 0 1
              else
                ${xrandr} --output "$screen" --rotate inverted
                ${xinput} set-prop "$device" --type=float "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
              fi

              # Counter-clockwise
              # xinput set-prop "GXTP7936:00 27C6:0123" --type=float "Coordinate Transformation Matrix" 0 -1 1 1 0 0 0 0 1

              # Clockwise
              # xinput set-prop "GXTP7936:00 27C6:0123" --type=float "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
            '')
            + "/bin/invert-screen";
          tail = true;
          interval = 10;
          # click-left = "${pkgs.astroid}/bin/astroid";
        };

        # "module/headsetswitch" = let
        #   pactl = "${pkgs.pulseaudioLight}/bin/pactl";
        #   grep = "${pkgs.gnugrep}/bin/grep";
        #   sed = "${pkgs.gnused}/bin/sed";
        # in {
        #   type = "custom/script";
        #   format-underline = "#0628FF";
        #   label = "%output%";
        #   exec = __concatStringsSep " " [
        #     "${pactl} info"
        #     "| ${grep} 'Default Sink'"
        #     "| ${sed} 's/.*analog-stereo//'"
        #     "| ${sed} 's/.*analog-stereo//'"
        #     "| ${sed} 's/.*auto_null/${icons.microphone-disconnected}/'"
        #     "| ${sed} 's/.*hdmi-stereo-extra.*/HDMI/'"
        #     "| ${sed} 's/.*headset_head_unit/${icons.microphone}/'"
        #     "| ${sed} 's/.*a2dp_sink/${icons.microphone-muted}/'"
        #     "| ${sed} 's/.*hdmi-stereo/HDMI/'"
        #   ];
        #
        #   tail = true;
        #   interval = 2;
        #   click-left = "${pactl} set-card-profile bluez_card.2C_41_A1_83_C7_98 a2dp_sink";
        #   click-right = "${pactl} set-card-profile bluez_card.2C_41_A1_83_C7_98 headset_head_unit";
        # };

        "module/time" = {
          type = "internal/date";
          interval = "5";

          time = "%I:%M";

          format-underline = "#2406E8";
          label = "%time%";
        };
      };
    };
  };
}
