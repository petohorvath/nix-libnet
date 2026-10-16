# test-standard v1: copied from the test-standard skill; do not edit here.
/*
  Turn a nix-unit entry point into a check, so its suites run under
  `nix flake check` and the project policy's `test`.

  `inputs`: the flake inputs; each argument the entry point declares,
  except `system`, comes from them or from `extraArgs`.
  `pkgs`: the package set that provides nix-unit and the system.
  `repo`: the repo name, the prefix of every derivation name.
  `srcDir`: a store path of the files the suites read.

  Returns a function that takes the entry's settings and returns its
  derivation, named `<repo>-<name>`.
*/
{
  inputs,
  pkgs,
  repo,
  srcDir,
}:
{
  kind,
  name ? kind,
  suites ? null,
  extraArgs ? { },
  requiredSystemFeatures ? [ ],
  postCheck ? "",
  jobs ? null,
}:
let
  inherit (pkgs) lib;

  entryPointPath = "${srcDir}/tests/${kind}";
  evaluationInputsPath = ../helpers/evaluation-inputs.nix;

  /*
    Walk a flake input into a tree of store paths, which
    `evaluation-inputs.nix` rebuilds into the flake inside the sandbox. The
    paths carry their store context, so they become inputs of the
    derivation and the sandbox fetches nothing.
  */
  inputTree =
    input:
    if (input._type or null) == "flake" then
      {
        path = input.outPath;
        inputs = lib.mapAttrs (_: inputTree) input.inputs;
      }
    else
      {
        path = input.outPath;
        flake = false;
      };

  inputArg =
    argName:
    if inputs ? ${argName} then
      let
        treePath = pkgs.writeText "${repo}-${name}-${argName}.json" (
          builtins.toJSON (inputTree inputs.${argName})
        );
      in
      "(import ${evaluationInputsPath}) (builtins.fromJSON (builtins.readFile ${treePath}))"
    else
      throw "${repo}-${name}: the entry point argument `${argName}` is neither a flake input nor in `extraArgs`.";

  inputArgNames = lib.subtractLists ([ "system" ] ++ builtins.attrNames extraArgs) (
    builtins.attrNames (builtins.functionArgs (import entryPointPath))
  );

  evalArgs = lib.genAttrs inputArgNames inputArg // extraArgs;

  evalFlags = lib.escapeShellArgs (
    lib.concatLists (
      lib.mapAttrsToList (argName: value: [
        "--arg"
        argName
        value
      ]) evalArgs
    )
    ++ [
      "--argstr"
      "system"
      pkgs.stdenv.hostPlatform.system
    ]
  );

  selectedSuites =
    if suites == null then "null" else "[ ${lib.concatMapStringsSep " " builtins.toJSON suites} ]";

  /*
    List the groups, the attrsets that directly hold `test*` attributes, as
    nix-unit attribute paths, one per line. They sit in the `groups`
    attribute because `nix eval` passes `--arg` values to the file's
    function only on the way to an attribute. The walk stops at a group, so
    nested attrsets in a group run in the group's process and each test
    runs once.
  */
  groupsPath = pkgs.writeText "${repo}-${name}-groups.nix" ''
    { ... }@args:
    let
      entryPoint = import ${entryPointPath};
      tests = entryPoint (
        builtins.intersectAttrs (builtins.functionArgs entryPoint) args
      );
      selectedSuites = ${selectedSuites};
      isTest = name: builtins.substring 0 4 name == "test";
      quote =
        name:
        if builtins.match "[a-zA-Z_][a-zA-Z0-9_'-]*" name != null then
          name
        else
          builtins.toJSON name;
      groupsOf =
        path: value:
        if !builtins.isAttrs value then
          [ ]
        else if builtins.any isTest (builtins.attrNames value) then
          [ (builtins.concatStringsSep "." (map quote path)) ]
        else
          builtins.concatMap (
            name: groupsOf (path ++ [ name ]) value.''${name}
          ) (builtins.attrNames value);
    in
    {
      groups = builtins.concatStringsSep "\n" (
        builtins.concatMap (name: groupsOf [ name ] tests.''${name}) (
          if selectedSuites == null then
            builtins.attrNames tests
          else
            selectedSuites
        )
      );
    }
  '';

  gcRootsFlag = lib.optionalString (lib.versionOlder pkgs.nix-unit.version "2.35") "--gc-roots-dir \"$TMPDIR/gc-roots/$index\"";
in
pkgs.runCommand "${repo}-${name}"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.nix-unit
    ];
    inherit requiredSystemFeatures;
  }
  ''
    export HOME="$TMPDIR"
    evalStore="$TMPDIR/eval-store"
    mkdir -p "$TMPDIR/logs" "$TMPDIR/gc-roots"

    nix --extra-experimental-features nix-command eval --raw \
      --store "$evalStore" --show-trace \
      ${evalFlags} --file ${groupsPath} groups > "$TMPDIR/groups"
    mapfile -t groups < "$TMPDIR/groups"
    if [ "''${#groups[@]}" -eq 0 ]; then
      echo "${repo}-${name}: tests/${kind} has no test groups" >&2
      exit 1
    fi

    maxJobs=${if jobs == null then "\${NIX_BUILD_CORES:-1}" else toString jobs}
    if [ "$maxJobs" -lt 1 ]; then
      maxJobs=1
    fi

    # Each nix-unit process evaluates one group, which bounds its memory.
    runGroup() {
      local index=$1 group=$2
      mkdir -p "$TMPDIR/gc-roots/$index"
      if nix-unit --quiet --show-trace --eval-store "$evalStore" \
        ${gcRootsFlag} ${evalFlags} --attr "$group" ${entryPointPath} \
        > "$TMPDIR/logs/$index" 2>&1; then
        touch "$TMPDIR/logs/$index.passed"
      fi
    }

    running=0
    for index in "''${!groups[@]}"; do
      if [ "$running" -ge "$maxJobs" ]; then
        wait -n || true
        running=$((running - 1))
      fi
      runGroup "$index" "''${groups[$index]}" &
      running=$((running + 1))
    done
    wait

    failed=0
    for index in "''${!groups[@]}"; do
      if [ -e "$TMPDIR/logs/$index.passed" ]; then
        echo "''${groups[$index]}: $(tail -n 1 "$TMPDIR/logs/$index")"
      else
        failed=1
        echo "''${groups[$index]} failed:"
        cat "$TMPDIR/logs/$index"
      fi
    done
    cat "$TMPDIR"/logs/[0-9]* \
      | sed -n 's|.* \([0-9][0-9]*\)/\([0-9][0-9]*\) successful.*|\1 \2|p' \
      | awk -v entry="${repo}-${name}" '
          { passed += $1; total += $2 }
          END { print passed "/" total " tests successful in " entry }
        '
    if [ "$failed" -ne 0 ]; then
      exit 1
    fi

    ${postCheck}
    touch "$out"
  ''
