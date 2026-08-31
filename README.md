самой простой способ запуска этого:

как нибудь качаете [nix](https://nixos.org/download/) и podman/docker

после просто заходите в папку с репозитроем и

1) `nix run '#http'` для запуска http сервера
2) `nix build '#ssh'` `podman load < result` `podman run -p 8022:22 --rm --tmpfs /tmp:rw,nosuid,nodev localhost/ssh_server:latest`
   если у вас docker то замените `podman` на `docker`

   по умолчанию есть ползователь `user` с паролем `123`. если надо изменить то смотрите файл flake. там(в районе 130 строки) будет `users = {`, вот там читайте что написано. и после изменениий снова 2 шаг с начала
