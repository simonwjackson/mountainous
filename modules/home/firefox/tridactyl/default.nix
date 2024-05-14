{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  age.secrets."user-simonwjackson-instapaper".file = ../../../../secrets/user-simonwjackson-instapaper.age;

  home.file.".local/state/nix/profile/bin/instapaper-add" = {
    text =
      /*
      bash
      */
      ''
        CURL=${lib.getExe pkgs.curl}
        user="simon@simonwjackson.com"
        password=$(cat ${config.age.secrets.user-simonwjackson-instapaper.path})
        url="$1"

        $CURL \
          -s \
          -d username="$user" \
          -d password="$password" \
          -d url="$url" \
          https://www.instapaper.com/api/add
      '';
    executable = true;
  };

  mountainous.tridactyl = {
    enable = true;
    extraSettings = ''
      " "" Send to phone
      " alias send_to_phone composite get_current_url | !s \$HOME/bin/url-to-phone
      " bind gp send_to_phone
      " bind 'gp hint -W send_to_phone
      "
      " "" MPV
      " alias mpvvideo composite get_current_url | js -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet(`$HOME/bin/xdg-video \$url`))
      " alias mpvaudio composite get_current_url | js -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet(`$HOME/bin/xdg-audio \$url`))
      "
      " bind gv mpvvideo
      " bind 'gv hint -W mpvvideo
      " bind 'gV hint -W mpvvideoenque
      " bind ga mpvaudio
      " bind 'ga hint -W mpvaudio
      " bind 'gA hint -W mpvaudioenque
      "
      " "" Taskwarrior
      " bind t composite get_current_url | js -p tri.excmds.fillcmdline(`! task add url:"$JS_ARG"`)
      "
      " command! addtask jsb -p tri.prompt("Enter task description").then(desc => tri.excmds.sh("task add " + desc + " annotate " + window.location.href))
      " bind --mode=normal s addtask
      " bind gi composite focusinput -l | editor
    '';

    modules = {
      youtube = {
        set = {
          "searchurls.youtube" = "https://www.youtube.com/results?search_query=";
        };

        bind = {
          gI = "tabopen https://www.youtube.com/watch?v=M3iOROuTuMA";
        };

        autocmd = {
          DocStart = {
            # "/www.youtube.com/watch\?v=.*" = ''
            #   js document.head.insertAdjacentHTML(" beforeend ", `<style>#player{display: none !important}</style>`)";
            # '';
          };
        };
      };

      google = {
        set = {
          searchengine = "google";
          "searchurls.google" = "https://encrypted.google.com/search?q=%s";
        };

        autocmd = {
          DocStart = {
            # Better google hints
            "/www.google.com/search.*" = {
              bind = {
                f = "hint -Jc a";
              };
            };
          };
        };

        bind = {
          ";m" = "composite hint -Jpipe img src | open images.google.com/searchbyimage?image_url=";
          ";M" = "composite hint -Jpipe img src | tabopen images.google.com/searchbyimage?image_url=";
          "'M" = "composite hint -pipe img src | jsb -p tri.excmds.tabopen('images.google.com/searchbyimage?image_url=' + JS_ARG)";
          "'m" = "composite hint -pipe img src | js -p tri.excmds.open('images.google.com/searchbyimage?image_url=' + JS_ARG)";
        };
      };

      mpv = {
        bind = {
          "'v" = "hint -W mpvsafe";
          "'gv" = "hint -W mpvvideo";
          ";gv" = "hint -qW mpvsafe";
          ";v" = "hint -W mpvsafe";
          gv = "mpvvideo";
        };

        command = {
          mpvaudio = ''
            composite get_current_url | js -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet(`$\{HOME}/bin/xdg-audio $\{url}`))
          '';
          mpvsafe = ''
            js -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet('mpv --no-terminal ' + url))
          '';
          mpvvideo = ''
            composite get_current_url | js -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet(`nix run nixpkgs#mpv -- $\{url}`))
          '';
        };
      };

      instapaper = {
        alias.readnow.eval_script = ''
          $\{HOME}/.config/tridactyl/scripts/instapaper_now.js
        '';
        command.readlater = ''
          composite get_current_url | jsb -p tri.excmds.shellescape(JS_ARG).then(url => tri.excmds.exclaim_quiet(`instapaper-add $\{url} &`))
        '';
        bind = {
          i = "readnow";
          I = "composite readlater; tabclose";
        };
      };
    };

    settings = {
      autocmd = {
        TriStart.".*" = "source_quiet";
        DocLoad."^https://github.com/tridactyl/tridactyl/issues/new$" = "ssue";
        DocStart = {
          ".*" = "bind f hint";
        };
      };
      set = {
        modeindicator = false;
        # editorcmd = '' ${pkgs.mountainous.popup-term}/bin/popup-term "nvim -f %f -c 'set noruler | set laststatus=0 | set noshowcmd | set cmdheight=1 | nnoremap <ENTER> :x<ENTER> | nnoremap <ESC><ESC> :q| nnoremap <C-s> :xa| inoremap <C-s> <C-o>:x<CR>'"'';
        "searchurls.amazon" = "https://www.amazon.com/s/ref=nb_sb_noss?url=search-alias%3Daps&field-keywords=";
        "searchurls.github" = "https://github.com/search?utf8=✓&q=";
        "searchurls.wikipedia" = "https://en.wikipedia.org/wiki/Special:Search/";
        "update.checkintervalsecs" = 86400;
        "update.lastchecktime" = 1694532473712;
        "update.lastnaggedversion" = "1.14.0";
        "update.nag" = true;
        "update.nagwait" = 7;
        configversion = 2.0;
        theme = "dark";
      };
      alias = {
        au = "autocmd";
        aucon = "autocontain";
        audel = "autocmddelete";
        audelete = "autocmddelete";
        authors = "credits";
        b = "tab";
        bN = "tabprev";
        bang = "exclaim";
        bang_s = "exclaim_quiet";
        bd = "tabclose";
        bdelete = "tabclose";
        bfirst = "tabfirst";
        blacklistremove = "autocmddelete DocStart";
        blast = "tablast";
        bn = "tabnext_gt";
        bnext = "tabnext_gt";
        bp = "tabprev";
        bprev = "tabprev";
        buffer = "tab";
        bufferall = "taball";
        clsh = "clearsearchhighlight";
        colors = "colourscheme";
        colorscheme = "colourscheme";
        colours = "colourscheme";
        containerremove = "containerdelete";
        current_url = "composite get_current_url | fillcmdline_notrail";
        drawingstop = "mouse_mode";
        eval_script = "js -p tri.native.read(`\${JS_ARG}`).then(r => eval(`(() => { \${r.content} })()`))";
        exto = "extoptions";
        extp = "extpreferences";
        extpreferences = "extoptions";
        get_current_url = "js document.location.href";
        h = "help";
        installnative = "nativeinstall";
        man = "help";
        mkt = "mktridactylrc";
        "mkt!" = "mktridactylrc -f";
        "mktridactylrc!" = "mktridactylrc -f";
        nativeupdate = "updatenative";
        noh = "clearsearchhighlight";
        nohlsearch = "clearsearchhighlight";
        o = "open";
        openwith = "hint -W";
        prefremove = "removepref";
        prefset = "setpref";
        q = "tabclose";
        qa = "qall";
        quit = "tabclose";
        reibadailty = "jumble";
        sanitize = "sanitise";
        "saveas!" = "saveas --cleanup --overwrite";
        send_to_phone = "composite get_current_url | !s \${HOME}/bin/url-to-phone";
        stop = "js window.stop()";
        t = "tabopen";
        tN = "tabprev";
        tabclosealltoleft = "tabcloseallto left";
        tabclosealltoright = "tabcloseallto right";
        tabfirst = "tab 1";
        tabgroupabort = "tgroupabort";
        tabgroupclose = "tgroupclose";
        tabgroupcreate = "tgroupcreate";
        tabgrouplast = "tgrouplast";
        tabgroupmove = "tgroupmove";
        tabgrouprename = "tgrouprename";
        tabgroupswitch = "tgroupswitch";
        tablast = "tab 0";
        tabm = "tabmove";
        tabnew = "tabopen";
        tabo = "tabonly";
        tfirst = "tabfirst";
        tlast = "tablast";
        tn = "tabnext_gt";
        tnext = "tabnext_gt";
        tp = "tabprev";
        tprev = "tabprev";
        tutorial = "tutor";
        unmute = "mute unmute";
        w = "winopen";
        zo = "zoom";
      };
      bind = {
        "$" = "scrollto 100 x";
        "'#" = "hint -#";
        "';" = "hint -;";
        "'A" = "hint -A";
        "'I" = "hint -I";
        "'O" = "hint -W fillcmdline_notrail open";
        "'P" = "hint -P";
        "'S" = "hint -S";
        "'T" = "hint -W fillcmdline_notrail tabopen";
        "'W" = "hint -W fillcmdline_notrail winopen";
        "'a" = "hint -a";
        "'b" = "hint -b";
        "'g#" = "hint -q#";
        "'g;" = "hint -q;";
        "'gA" = "hint -qA";
        "'gF" = "hint -qb";
        "'gI" = "hint -qI";
        "'gP" = "hint -qP";
        "'gS" = "hint -qS";
        "'gb" = "hint -qb";
        "'gf" = "hint -q";
        "'gi" = "hint -qi";
        "'gk" = "hint -qk";
        "'gp" = "hint -W send_to_phone";
        "'gr" = "hint -qr";
        "'gs" = "hint -qs";
        "'gw" = "hint -qw";
        "'gy" = "hint -qy";
        "'i" = "hint -i";
        "'k" = "hint -k";
        "'o" = "hint";
        "'p" = "hint -p";
        "'r" = "hint -r";
        "'s" = "hint -s";
        "'t" = "hint -W tabopen";
        "'w" = "hint -w";
        "'y" = "hint -y";
        "'z" = "hint -z";
        "." = "repeat";
        ":" = "fillcmdline_notrail";
        ";#" = "hint -#";
        ";;" = "hint -;";
        ";A" = "hint -A";
        ";I" = "hint -I";
        ";K" = "hint -K";
        ";O" = "hint -W fillcmdline_notrail open";
        ";P" = "hint -P";
        ";S" = "hint -S";
        ";T" = "hint -W fillcmdline_notrail tabopen";
        ";V" = "hint -V";
        ";W" = "hint -W fillcmdline_notrail winopen";
        ";X" = ''hint -F e => { const pos = tri.dom.getAbsoluteCentre(e); tri.excmds.exclaim_quiet('xdotool mousemove --sync ' + window.devicePixelRatio * pos.x + ' ' + window.devicePixelRatio * pos.y + '; xdotool keydown ctrl+shift; xdotool click 1; xdotool keyup ctrl+shift')} '';
        ";Y" = "hint -cF img i => tri.excmds.yankimage(tri.urlutils.getAbsoluteURL(i.src))";
        ";a" = "hint -a";
        ";b" = "hint -b";
        ";g#" = "hint -q#";
        ";g;" = "hint -q;";
        ";gA" = "hint -qA";
        ";gF" = "hint -qb";
        ";gI" = "hint -qI";
        ";gP" = "hint -qP";
        ";gS" = "hint -qS";
        ";ga" = "hint -qa";
        ";gb" = "hint -qb";
        ";gf" = "hint -q";
        ";gi" = "hint -qi";
        ";gk" = "hint -qk";
        ";gp" = "hint -qp";
        ";gr" = "hint -qr";
        ";gs" = "hint -qs";
        ";gw" = "hint -qw";
        ";gy" = "hint -qy";
        ";h" = "hint -h";
        ";i" = "hint -i";
        ";k" = "hint -k";
        ";o" = "hint";
        ";p" = "hint -p";
        ";r" = "hint -r";
        ";s" = "hint -s";
        ";t" = "hint -W tabopen";
        ";w" = "hint -w";
        ";x" = ''hint -F e => { const pos = tri.dom.getAbsoluteCentre(e); tri.excmds.exclaim_quiet('xdotool mousemove --sync ' + window.devicePixelRatio * pos.x + ' ' + window.devicePixelRatio * pos.y + '; xdotool click 1')}'';
        ";y" = "hint -y";
        ";z" = "hint -z";
        "<<" = "tabmove -1";
        "<A-m>" = "mute toggle";
        "<A-p>" = "pin";
        "<AC-Escape>" = "mode ignore";
        "<AC-`>" = "mode ignore";
        "<C-[>" = "composite mode normal ; hidecmdline";
        "<C-a>" = "urlincrement 1";
        "<C-b>" = "scrollpage -1";
        "<C-d>" = "scrollpage 0.5";
        "<C-e>" = "scrollline 10";
        "<C-f>" = "scrollpage 1";
        "<C-i>" = "jumpnext";
        "<C-o>" = "jumpprev";
        "<C-u>" = "scrollpage -0.5";
        "<C-v>" = "nmode ignore 1 mode normal";
        "<C-x>" = "urlincrement -1";
        "<C-y>" = "scrollline -10";
        "<Escape>" = "composite mode normal ; hidecmdline";
        "<F1>" = "help";
        "<S-Escape>" = "mode ignore";
        "<S-Insert>" = "mode ignore";
        ">>" = "tabmove +1";
        "[[" = "followpage prev";
        "[c" = "urlincrement -1";
        "]]" = "followpage next";
        "]c" = "urlincrement 1";
        "^" = "scrollto 0 x";
        "`" = "gobble 1 markjump";
        "g!" = "jumble";
        "g$" = "tablast";
        "g;" = "changelistjump -1";
        "g?" = "rot13";
        "g^" = "tabfirst";
        "gx$" = "tabclosealltoright";
        A = "bmark";
        D = "composite tabprev; tabclose #";
        F = "hint -b";
        G = "scrollto 100";
        J = "tabnext";
        K = "tabprev";
        M = "gobble 1 quickmark";
        O = "current_url open";
        P = "clipboard tabopen";
        R = "reloadhard";
        T = "current_url tabopen";
        U = "undo window";
        W = "current_url winopen";
        ZZ = "qall";
        a = "current_url bmark";
        d = "composite tabdetach";
        f = "hint";
        g0 = "tabfirst";
        gF = "hint -qb";
        gH = "home true";
        gT = "tabprev";
        gU = "urlroot";
        ga = "tabaudio";
        gg = "scrollto 0";
        gh = "home";
        gi = "focusinput -l";
        gp = "send_to_phone";
        gt = "tabnext_gt";
        gu = "urlparent";
        gx0 = "tabclosealltoleft";
        h = "back";
        j = "scrollline 10";
        k = "scrollline -10";
        l = "forward";
        m = "gobble 1 markadd";
        o = "fillcmdline open";
        p = "clipboard open";
        r = "reload";
        s = "addtask";
        t = "fillcmdline tabopen";
        u = "undo";
        v = "hint -h";
        w = "fillcmdline winopen";
        x = "stop";
        yc = "clipboard yankcanon";
        ym = "clipboard yankmd";
        yo = "clipboard yankorg";
        ys = "clipboard yankshort";
        yt = "clipboard yanktitle";
        yy = "clipboard yank";
        zI = "zoom 3";
        zM = "zoom 0.5 true";
        zO = "zoom 0.3";
        zR = "zoom -0.5 true";
        zi = "zoom 0.1 true";
        zm = "zoom 0.5 true";
        zo = "zoom -0.1 true";
        zr = "zoom -0.5 true";
        zz = "zoom 1";
      };
      unbind = [
        "s"
        "S"
        "d"
        "B"
        "b"
        "gf"
      ];
    };
  };
}
