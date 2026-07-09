{ inputs, flake-utils }:
input-names:
flake-utils.lib.eachDefaultSystem (system: {
  packages = builtins.foldl' (
    acc: input-name:
    if builtins.hasAttr system inputs.${input-name}.packages then
      acc
      // {
        ${input-name} = inputs.${input-name}.packages.${system}.default;
      }
      // builtins.removeAttrs inputs.${input-name}.packages.${system} [ "default" ]
    else
      acc
  ) { } input-names;
})
