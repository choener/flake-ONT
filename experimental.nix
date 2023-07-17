
# Experimental stuff that currently does not work!

{
      # BUG: trying to build lib-pod5 from source is complicated at best. Needs an older version of
      # conan, and other depends. Will only try if *really* necessary.

      #lib-pod5 = final.stdenv.mkDerivation rec {
      #  name = "lib_pod5";
      #  version = "0.2.3";
      #  src = final.fetchFromGitHub {
      #    owner = "nanoporetech";
      #    repo = "pod5-file-format";
      #    rev = "refs/tags/${version}";
      #    hash = "sha256-4LX6gms70tqe51T8/UjS+yHV63j2i0/b59i55t2RbGM=";
      #    fetchSubmodules = true;
      #  };
      #  nativeBuildInputs = with final; [ cmake arrow-cpp boost flatbuffers zstd conan pkgconfig (final.python310.withPackages (p: [p.setuptools_scm p.pybind11])) gcc10 ];
      #  configurePhase = ''
      #    ls -alh
      #    python --version
      #    python -m setuptools_scm
      #    #bang
      #    #python -m pod5_make_version
      #    #mkdir -p build
      #    #cd build
      #    #cmake -DBUILD_PYTHON_WHEEL=OFF -DCMAKE_BUILD_TYPE=Release ..
      #    #make -j
      #    bang
      #  '';
      #};
}
