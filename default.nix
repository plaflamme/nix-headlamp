{
  stdenv,
  lib,
  buildGoModule,
  buildNpmPackage,
  fetchFromGitHub,
  electron_39,
  rsync,
  makeDesktopItem,
  copyDesktopItems,
}:
let
  electron = electron_39;
  version = "0.38.0";
  src = fetchFromGitHub {
    owner = "kubernetes-sigs";
    repo = "headlamp";
    rev = "v${version}";
    hash = "sha256-h5FUU18pXOoxPqkoNnhL7gf7wtLwvuIsJv9CDBs1U5o=";
  };
  backend = buildGoModule {
    pname = "headlamp-backend";

    inherit src version;

    vendorHash = "sha256-x71wjOXk222JmIZGU2gKKXsqjTKMpMS8YPVhPKS4ssI=";

    enableParallelBuilding = true;

    modRoot = "./backend";
    subPackages = [ "cmd" ];
    postInstall = ''
      mv $out/bin/cmd $out/bin/headlamp-server
    '';

  };
  frontend = buildNpmPackage {
    pname = "headlamp-frontend";
    inherit src version;

    sourceRoot = "${src.name}/frontend";

    npmDepsHash = "sha256-deHlkxx6gdCt+xIgpt5Rodo1oDxyB6Xso+W19SXieCo=";

    postPatch = ''
      substituteInPlace make-env.js --replace-fail "const gitVersion = execSync('git rev-parse HEAD').toString().trim();" 'const gitVersion="${version}"'

    '';

    postInstall = ''
      cp -r build $out/
    '';
  };
in
buildNpmPackage {
  pname = "headlamp";

  inherit
    src
    version
    frontend
    backend
    ;

  sourceRoot = "${src.name}/app";

  npmDepsHash = "sha256-Gtq/gNxSLfmq7qnaYFaKeHXlHClMAqYvgsfnCIlLKd8=";

  nativeBuildInputs = [
    electron
    rsync # see scripts/after-sync.js
    copyDesktopItems
  ];

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  postPatch = ''
    substituteInPlace package.json --replace-fail '"beforeBuild": "./scripts/build-backend.js",' ""
    substituteInPlace package.json --replace-fail '../backend/headlamp-server' '${backend}/bin/headlamp-server'
    substituteInPlace package.json --replace-fail '../frontend/build' '${frontend}/build'

    # electron complains otherwise
    substituteInPlace package.json --replace-fail '"asar": false,' ""
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    # https://github.com/electron/electron/issues/31121
    substituteInPlace electron/main.ts \
      --replace-fail "process.resourcesPath" "'$out/share/headlamp/resources'"
  '';
  buildPhase = ''
    runHook preBuild

    npm run copy-icons
    npm run copy-plugins
    npm run compile-electron
    npm run prod-deps
    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          cp -r ${electron.dist}/Electron.app ./
          find ./Electron.app -name 'Info.plist' | xargs -d '\n' chmod +rw

          npm exec electron-builder -- --dir --publish never \
            -c.electronDist=./ \
            -c.electronVersion=${electron.version} \
            -c.npmRebuild=false
        ''
      else
        ''
          npm exec electron-builder -- --dir --publish never \
            -c.electronDist=${electron.dist} \
            -c.electronVersion=${electron.version} \
            -c.npmRebuild=false
        ''
    }

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          mkdir -p $out/Applications
          cp -r dist/*/Headlamp.app $out/Applications/
        ''
      else
        ''
          mkdir -p $out/share/headlamp
          pushd dist/linux-unpacked
          # TODO: some of these point into /build, not sure how to avoid installing these.
          rm -rf resources/app/node_modules/*/node_modules/.bin
          cp -r locales resources{,.pak} $out/share/headlamp
          popd

          makeWrapper ${lib.getExe electron} $out/bin/headlamp \
            --add-flags $out/share/headlamp/resources/app.asar \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
            --inherit-argv0

          for size in 192 512; do
            mkdir -p $out/share/icons/hicolor/"$size"x"$size"/apps
            ln -s \
              $out/share/headlamp/resources/frontend/android-chrome-"$size"x"$size".png \
              $out/share/icons/hicolor/"$size"x"$size"/apps/headlamp.png
          done
          for size in 16 32; do
            mkdir -p $out/share/icons/hicolor/"$size"x"$size"/apps
            ln -s \
              $out/share/headlamp/resources/frontend/favicon-"$size"x"$size".png \
              $out/share/icons/hicolor/"$size"x"$size"/apps/headlamp.png
          done
        ''
    }

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "headlamp";
      desktopName = "Headlamp";
      comment = "A user-friendly Kubernetes UI focused on extensibility";
      icon = "headlamp";
      exec = "headlamp";
      categories = [ ];
      mimeTypes = [ ];
    })
  ];

  meta = with lib; {
    description = "Headlamp is a user-friendly Kubernetes UI focused on extensibility";
    homepage = "https://headlamp.dev";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    mainProgram = "headlamp";
  };
}
