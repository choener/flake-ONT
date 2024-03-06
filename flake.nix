{
  description = "Flake for random ONT stuff";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
    read5 = { url = "github:rnajena/read5"; flake = false; };
  };

  outputs = outputs@{ self, nixpkgs, flake-utils, devshell, ... }: let

    # each system
    eachSystem = system: let
      config = { allowUnfree = true;};
      pkgs = import nixpkgs {
        inherit system;
        inherit config;
        overlays = [ self.overlay devshell.overlays.default ];
      };
      python310 = pkgs.python310.override { packageOverrides = pkgs.pythonOverlay; };
      pyenv = python310.withPackages (p: [
        p.h5py
        p.lib-pod5
        p.pod5
        p.read5
      ]);

    in rec {
      devShell = let
      in pkgs.devshell.mkShell {
        devshell.packages = [ pyenv ];
        env = [
          { name = "MKL_NUM_THREADS"; value = 1; }
          { name = "OMP_NUM_THREADS"; value = 1; }
          { name = "HDF5_PLUGIN_PATH"; value = "${pkgs.hdf5}/lib:${pkgs.vbz-hdf-plugin}/lib"; }
        ];
      };
      # TODO required for "nix develop .#lib-pod5"
      packages = {}; # { inherit (pkgs) lib-pod5; };
    }; #eachSystem

    overlay = final: prev: rec {

      vbz-hdf-plugin = with final; stdenv.mkDerivation rec {
        pname = "vbz_compression";
        version = "1.0.2";
        src = pkgs.fetchurl {
          url = "https://github.com/nanoporetech/vbz_compression/releases/download/1.0.2/ont-vbz-hdf-plugin_1.0.2-1.bionic_amd64.deb";
          sha256 = "sha256-Ipy9fOIJ+keve8t+4XMa/vd0YPmTzGoAddhollv1xZQ=";
        };
        unpackPhase = ''
          ${pkgs.dpkg}/bin/dpkg -x ${src} .
        '';
        installPhase = ''
          mkdir -p $out/lib
          mv usr/local/hdf5/lib/plugin/libvbz_hdf_plugin.so $out/lib
        '';
        buildInputs = with pkgs; [ zstd stdenv.cc.cc.lib ];
        nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
      };

      # Overlay for python packages.
      # TODO This should be specialized to different python versions where necessary / possible.
      pythonOverlay = self: super: {

        lib-pod5 = super.buildPythonPackage rec {
          pname = "lib_pod5";
          version = "0.2.4";
          src = super.fetchPypi {
            inherit pname version format;
            dist = "cp310";
            python = "cp310";
            abi = "cp310";
            platform = "manylinux_2_17_x86_64.manylinux2014_x86_64";
            sha256 = "sha256-FShiq8FcfDznMJJ3NfEMtGgw/bNTNEEG5WQdFCODirM=";
          };
          format = "wheel";
          propagatedBuildInputs = with super; [ numpy stdenv.cc.cc.lib ];
        }; #lib-pod5

        pod5 = super.buildPythonPackage rec {
          pname = "pod5";
          version = "0.2.4";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "sha256-8grlI45gxMkfAUOzlx+miO+B54V8X7X/vGUREpaji7E=";
          };
          propagatedBuildInputs = with super; [ more-itertools tqdm pyarrow iso8601 packaging pytz h5py self.vbz-h5py-plugin self.lib-pod5 polars ];
          prePatch = ''
            substituteInPlace pyproject.toml \
              --replace "pyarrow ~= 11.0.0" "pyarrow ~= 12.0.0" \
              --replace "polars~=0.17.12" "polars ~= 0.17.11"
          '';
        }; #pod5

        vbz-h5py-plugin = super.buildPythonPackage rec {
          pname = "vbz_h5py_plugin";
          version = "1.0.1";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "sha256-x4RFi7Cq1jA0dMsvEJVheRFrNVVYA/0RVOtO82JRk0E=";
          };
          propagatedBuildInputs = with super; [ h5py ];
        }; #vbz-h5py-plugin

        pyslow5 = super.buildPythonPackage rec {
          pname = "pyslow5";
          version = "1.0.0";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "sha256-GWnxplfxBRsYlCzZGATwbTMktMvPLUI6j5R963Tx0Mw=";
          };
          propagatedBuildInputs = with super; [ numpy cython prev.zlib ];
        }; #pyslow5

        read5 = self.buildPythonPackage rec {
          pname = "read5";
          version = "main";
          src = outputs.read5;
          #src = final.fetchFromGitHub {
          #  owner = "JannesSP";
          #  repo = pname;
          #  rev = "08a336080c52104f9fed2aa6affd83b70e7ed2f4";
          #  hash = "sha256-kB81mXG0RJFOdP2aQP9dWCFPx7ospoSH42aoLRLhtUU=";
          #};
          propagatedBuildInputs = with self; [ h5py pod5 pyslow5 vbz-h5py-plugin ];
          doCheck = true;
          checkPhase = ''
            export HDF5_PLUGIN_PATH="${final.pkgs.hdf5}/lib:${self.vbz-h5py-plugin}/lib/python3.10/site-packages/vbz_h5py_plugin/lib"
            ${self.pytest}/bin/pytest
          '';
        }; #read5

      }; #packageOverridesr
    };

  in
    flake-utils.lib.eachDefaultSystem eachSystem // { inherit overlay; };
}
