# Oxford Nanopore - related Software

This flake provides a number of Python packages that are useful for dealing with Oxford Nanopore
data. In particular, the Python packages ``pod5``, ``slow5``, and ``read5`` are packaged up.

One should use ``Python 3.10``, no other version was tested.
Apply the overlay, the override ``python310`` packages with the ``pythonOverlay``, which provides
those packages.

```nix
pkgs = import nixpkgs {
  inherit system;
  inherit config;
  overlays = [ self.overlay devshell.overlays.default ];
};
python310 = pkgs.python310.override { packageOverrides = pkgs.pythonOverlay; };
```


# Notes

- I tried building ``lib-pod5`` from source, but it uses ``conan`` and is annoying to build. Cf.
  ``experimental.nix``.
