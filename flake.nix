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
        devshell.packages = with pkgs; [ pyenv lib-pod5 ];
        env = [
          { name = "MKL_NUM_THREADS"; value = 1; }
          { name = "OMP_NUM_THREADS"; value = 1; }
        ];
        imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
      };
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
        nativeBuildInputs = with final; [ cmake arrow-cpp boost flatbuffers zstd conan pkgconfig (final.python310.withPackages (p: [p.setuptools_scm])) ];
        configurePhase = ''
          ls -alh
          #python -m setuptools_scm
          #bang
          python -m pod5_make_version
          mkdir -p build
          cd build
          cmake -DBUILD_PYTHON_WHEEL=OFF -DCMAKE_BUILD_TYPE=Release ..
          make -j
          bang
        '';
      };
      python310 = prev.python310.override {
        packageOverrides = self: super: {
          # BUG Uses a wheel; this could be problematic, in particular with regards to lib_pod5
          # trying to access libstdc++
          lib-pod5 = super.buildPythonPackage rec {
            pname = "lib_pod5";
            version = "0.2.3";
            src = prev.fetchurl {
              url = "https://files.pythonhosted.org/packages/4e/7b/7adb7c9361a6f602b6d47fd928dc99e70625e4375818d0f4267e954662fc/lib_pod5-0.2.3-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
              sha256 = "sha256-PCzm4y3V3Jv1YV2vpyxTL8rXpvPolz8OHiUFcbgRa9g=";
            };
            format = "wheel";
            #src = final.fetchFromGitHub {
            #  owner = "nanoporetech";
            #  repo = "pod5-file-format";
            #  rev = "refs/tags/${version}";
            #  hash = "sha256-4LX6gms70tqe51T8/UjS+yHV63j2i0/b59i55t2RbGM=";
            #};
            #sourceRoot = "${src}/python/lib_pod5";
            #doCheck = false;
            propagatedBuildInputs = with super; [ numpy setuptools final.gcc-unwrapped.lib setuptools wheel pybind11 ];
          }; #lib-pod5
          pod5 = super.buildPythonPackage rec {
            pname = "pod5";
            version = "0.2.3";
            src = self.fetchPypi {
              inherit pname version;
              sha256 = "sha256-LrclrcxCC6TIFGSCP+QADWPV8Oaqe9GoPTepCHA9GKA=";
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
              rev = "fec71026bc60a4ddc1082d860e10abe8c932bd6f";
              hash = "sha256-A9B6GUAQHs4DGtj6iSNhBLHguCl/Nv55SydbTElufAU=";
            };
            propagatedBuildInputs = with self; [ h5py pod5 pyslow5 ];
            doCheck = false;
          }; #read5
        }; #packageOverridesr
      };
    };

  in
    flake-utils.lib.eachDefaultSystem eachSystem // { inherit overlay; };
}
