{
  description = "Flake for random ONT stuff";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    flake-utils.url = "github:numtide/flake-utils";
    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, flake-utils, devshell }: let

    # each system
    eachSystem = system: let
      config = { allowUnfree = true;};
      pkgs = import nixpkgs {
        inherit system;
        inherit config;
        overlays = [ self.overlay devshell.overlays.default ];
      };
      pyenv = pkgs.python310.withPackages (p: [
        p.h5py
        p.lib-pod5
        p.pod5
        p.read5
      ]);

    in rec {
      devShell = let
      in pkgs.devshell.mkShell {
        devshell.packages = with pkgs; [ pyenv ]; # pyenv lib-pod5
        env = [
          { name = "MKL_NUM_THREADS"; value = 1; }
          { name = "OMP_NUM_THREADS"; value = 1; }
          { name = "HDF5_PLUGIN_PATH"; value = "${pkgs.hdf5}/lib"; }
        ];
        #imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
      };
      packages = { inherit (pkgs) lib-pod5; };
    }; #eachSystem

    overlay = final: prev: rec {
      lib-pod5 = final.stdenv.mkDerivation rec {
        name = "lib_pod5";
        version = "0.2.3";
        src = final.fetchFromGitHub {
          owner = "nanoporetech";
          repo = "pod5-file-format";
          rev = "refs/tags/${version}";
          hash = "sha256-4LX6gms70tqe51T8/UjS+yHV63j2i0/b59i55t2RbGM=";
          fetchSubmodules = true;
        };
        nativeBuildInputs = with final; [ cmake arrow-cpp boost flatbuffers zstd conan pkgconfig (final.python310.withPackages (p: [p.setuptools_scm p.pybind11])) gcc10 ];
        configurePhase = ''
          ls -alh
          python --version
          python -m setuptools_scm
          #bang
          #python -m pod5_make_version
          #mkdir -p build
          #cd build
          #cmake -DBUILD_PYTHON_WHEEL=OFF -DCMAKE_BUILD_TYPE=Release ..
          #make -j
          bang
        '';
      };
      python310 = prev.python310.override {
        packageOverrides = self: super: {
          # BUG Uses a wheel; this could be problematic, in particular with regards to lib_pod5
          # trying to access libstdc++
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
            propagatedBuildInputs = with super; [ numpy stdenv.cc.cc.lib ]; # setuptools final.gcc-unwrapped.lib setuptools wheel pybind11 ];
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
            src = final.fetchFromGitHub {
              owner = "JannesSP";
              repo = pname;
              rev = "08a336080c52104f9fed2aa6affd83b70e7ed2f4";
              hash = "sha256-WC/Axptjl99mv9+muCZHglM97ndc9bPV+Jm3JWTacBw=";
            };
            propagatedBuildInputs = with self; [ h5py pod5 pyslow5 vbz-h5py-plugin ];
            doCheck = true;
            checkPhase = ''
              export HDF5_PLUGIN_PATH="${final.pkgs.hdf5}/lib:${self.vbz-h5py-plugin}/lib/python3.10/site-packages/vbz_h5py_plugin/lib"
              ${self.pytest}/bin/pytest
            '';
          }; #read5
        }; #packageOverridesr
      };
    };

  in
    flake-utils.lib.eachDefaultSystem eachSystem // { inherit overlay; };
}
