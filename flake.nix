{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem(system: let
    pkgs = import nixpkgs { inherit system; };

    generator = pkgs.pkgsStatic.stdenv.mkDerivation {
      name = "generator";
      src = ./ssh_server/utils/generator.c;
      dontUnpack = true;
      buildPhase = ''
        $CC -static "$src" -o generator
      '';
      installPhase = ''
        mkdir -p "$out/bin"
        cp generator "$out/bin"
      '';
    };

    checker = pkgs.pkgsStatic.stdenv.mkDerivation {
      name = "checker";
      src = ./ssh_server/utils/checker.c;
      dontUnpack = true;
      buildPhase = ''
        $CC -static "$src" -o checker
      '';
      installPhase = ''
        mkdir -p "$out/bin"
        cp checker "$out/bin"
      '';
    };

    check = ./ssh_server/utils/check;
    
    busybox = pkgs.pkgsStatic.busybox.overrideAttrs (old: {
      configurePhase = ''
        make allnoconfig

        function parseconfig {
          while IFS=" " read NAME OPTION; do
            if ! [[ "$NAME" =~ ^CONFIG_ ]]; then continue; fi

            echo "parseconfig: removing $NAME"
            sed -i /$NAME'\(=\| \)'/d .config

            echo "parseconfig: setting $NAME=$OPTION"
            echo "$NAME=$OPTION" >> .config
          done
        }

        cat << EOF | parseconfig
        CONFIG_PREFIX "$out"
        CONFIG_CROSS_COMPILER_PREFIX "${pkgs.pkgsStatic.stdenv.cc.targetPrefix}"
        CONFIG_INSTALL_NO_USR y
        CONFIG_HAVE_DOT_CONFIG y
        CONFIG_LFS y
        CONFIG_TC n

        CONFIG_INSTALL_APPLET_HARDLINKS y
        CONFIG_INSTALL_APPLET_SYMLINKS n
        CONFIG_BUSYBOX y
        CONFIG_STATIC y

        CONFIG_CONFIG_READPROFILE y
        CONFIG_SHOW_USAGE y
        CONFIG_LONG_OPTS y
        CONFIG_FEATURE_EDITING y
        CONFIG_FEATURE_EDITING_MAX_LEN 1024
        CONFIG_UNICODE_SUPPORT y
        CONFIG_LOCALE_SUPPORT y
        CONFIG_UNICODE_USING_LOCALE y
        CONFIG_FEATURE_EDITING_HISTORY 200
        CONFIG_FEATURE_EDITING_SAVEHISTORY y
        CONFIG_FEATURE_REVERSE_SEARCH y
        CONFIG_FEATURE_TAB_COMPLETION y
        CONFIG_FEATURE_HUMAN_READABLE y
        CONFIG_FEATURE_VERBOSE y
        CONFIG_FEATURE_SHADOWPASSWDS y
        CONFIG_FEATURE_ADDUSER_TO_GROUP y
        CONFIG_USE_BB_SHADOW y
        CONFIG_FEATURE_SH_EXTRA_QUIET y

        CONFIG_CAT y
        CONFIG_CHMOD y
        CONFIG_CP y
        CONFIG_ECHO y
        CONFIG_GREP y
        CONFIG_HEAD y
        CONFIG_LS y
        CONFIG_MKDIR y
        CONFIG_MORE y
        CONFIG_MV y
        CONFIG_PWD y
        CONFIG_RMDIR y
        CONFIG_RM y
        CONFIG_SORT y
        CONFIG_TAIL y
        CONFIG_TOUCH y
        CONFIG_WC y
        CONFIG_DIFF y
        CONFIG_MKTEMP y
        CONFIG_CHMOD y

        CONFIG_FEATURE_LS_FILETYPES y
        CONFIG_FEATURE_LS_FOLLOWLINKS y
        CONFIG_FEATURE_LS_RECURSIVE y
        CONFIG_FEATURE_LS_WIDTH y
        CONFIG_FEATURE_LS_SORTFILES y
        CONFIG_FEATURE_LS_TIMESTAMPS y
        CONFIG_FEATURE_LS_USERNAME y
        CONFIG_FEATURE_LS_COLOR y
        CONFIG_FEATURE_LS_COLOR_IS_DEFAULT y
        EOF
        make oldconfig
        runHook postConfigure
      '';

      postInstall = ''
        rm -f $out/bin/busybox
      '';
    });

    dropbear = pkgs.pkgsStatic.dropbear;

    users = {
      user = {
        uid = 1000; # когда-нибудь я сделаю автоматическую нумерацию, а пока увеличивайте это число сами каждый раз
        shadow = "$6$6t9WB8SC6vCOS41Z$jWdvA/cuZ7grsBA8bSCf8TWpyOnjZMuFElTlfsp8acHZPtxzvpvxJ0Xxx26XwkMs4KqtPsax0o3kaDN6cL4Fr/"; # тут результат команды mkpasswd -m sha512crypt <пароль>
      };
    };

    ssh_user_list = pkgs.lib.concatStringsSep ","
      (pkgs.lib.mapAttrsToList (name: _: name) users);

    ssh_passwd = pkgs.lib.concatStringsSep "\n"
      (pkgs.lib.mapAttrsToList (name: user: "${name}:x:${toString user.uid}:1000::/home/${name}:/bin/sh") users);

    ssh_shadow = pkgs.lib.concatStringsSep "\n"
      (pkgs.lib.mapAttrsToList (name: user: "${name}:${user.shadow}:::99999:7:::") users);
  in {
    packages = {
      http = pkgs.buildNpmPackage {
        name = "http_server";
        src = ./http_server;
        npmDepsHash = "sha256-7NCPWlK0YwXitXMOBcnrckB7UigqnH3JPLJ2AS5RXhM=";
        nativeBuildInputs = with pkgs; [ nodejs ];
        dontNpmBuild = true;
      };

      inherit generator checker check;

      ssh = pkgs.dockerTools.buildLayeredImage {
        name = "ssh_server";
        tag = "latest";
        fakeRootCommands = ''
          mkdir -p ./etc ./sbin ./bin ./home ./etc/dropbear ./dev ./sys ./proc ./run ./tmp

          echo "export PATH=/bin" > etc/profile

          cp "${busybox}"/bin/{sh,mkdir,echo,cat,touch,ls,more,cp,rm,rmdir,mv,wc,head,tail,sort,grep,chmod} bin
          cp "${busybox}"/bin/* sbin
          cp "${dropbear}"/bin/{dropbear,dropbearkey} sbin

          touch etc/passwd etc/group etc/shadow etc/shells

          echo "root:x:0:0:root:/:/sbin/sh" >> etc/passwd
          echo "root:!:0:root" >> etc/group
          echo "root:*:19500:0:99999:7:::" >> etc/shadow
          echo "/sbin/sh" >> etc/shells

          echo "/bin/sh" >> etc/shells
          echo 'users:x:1000:${ssh_user_list}' >> etc/group
          echo '${ssh_passwd}' >> etc/passwd
          echo '${ssh_shadow}' >> etc/shadow

          cp "${generator}/bin/generator" sbin
          cp "${checker}/bin/checker" sbin
          cp "${check}" sbin/check

          #${pkgs.libcap}/bin/setcap CAP_DAC_OVERRIDE=ep sbin/checker

          chmod 700 .
          chmod 755 bin -R
          chmod 700 dev -R
          chmod 611 etc
          chmod 600 etc/* -R
          chmod 644 etc/passwd
          chmod 644 etc/group
          chmod 644 etc/shells
          chmod 644 etc/profile
          chmod 611 home -R
          chmod 600 proc -R
          chmod 755 run
          chmod 1777 tmp
          chmod 711 sbin
          chmod 700 sbin/* -R
          chmod o+x sbin/generator
          chmod o+x sbin/checker
          chmod u+s sbin/checker
          chmod o+rx sbin/check
          chmod o+x sbin/diff
          chmod o+x sbin/rm
          chmod o+x sbin/mktemp
          chmod 600 sys -R

          ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: _: "mkdir -p ./home/${name}") users)}
          ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: user: "chown ${toString user.uid}:1000 ./home/${name}") users)}
          ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (name: user: "chmod 700 ./home/${name}") users)}
        '';
        config = {
          Cmd = [ "/sbin/sh" "-c" "/sbin/dropbear -R -F -w -m" ];
          ExposePorts = {
            "22/tcp" = {};
          };
        };
      };
    };
  });
}
