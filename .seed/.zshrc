# Run any extra scripts.
if [[ -d ~/.zsh-extra ]]; then
  for f in ~/.zsh-extra/*; do source $f; done
fi
