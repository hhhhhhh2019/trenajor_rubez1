# Требования к ssh серверу

ожидается что к серверу можно подключаться по паролю и что на сервере есть файлы /sbin/check, /sbin/generator, /sbin/checker (исходники этих файлов лежат в папке sources)

чтобы /sbin/checker работал без проблем, ему надо добавить CAP_DAC_OVERRIDE (`setcap CAP_DAC_OVERRIDE=+ep /usr/sbin/checker`)

# Способы создания подходящего ssh сервера

если вы хотите, чтобы было реально как на рубежке, то читайте как работают jail-ы в freebsd. я не знаю как ими пользоваться.

## podman/docker

создать конейнер можно такой командой
`podman run -itd --name=rubez --memory=512M -p 8022:22 debian`

далее обновляем репозитории и устанавливаем dropbear(можно и openssh, но dropbear меньше весит)
`apt update`
`apt install dropbear`

далее нужно достать бинарники генератора и проверяльщика, вы можете скомпилировать их прямо в контейнере
`apt install gcc git libcap2-bin`
`git clone https://github.com/hhhhhhh2019/trenajor_rubez1`
`cd trenajor_rubez1`
`gcc sources/generator.c -o /usr/sbin/generator`
`gcc sources/checker.c -o /usr/sbin/checker`
`setcap CAP_DAC_OVERRIDE=+ep /usr/sbin/checker`
`cp sources/check /usr/sbin/check`

чтобы запустить ssh сервер просто вызываем dropbear
`dropbear`

если `pidof dropbear` выдает какое-то число, то все хорошо. 
если нет, можете попробовать вызвать `dropbear -E -F` и посмотреть, что выводит

чтобы добавлять пользоваетелей используется
`useradd -m <имя пользователя>`
чтобы поставить пароль для пользователя
`passwd <имя пользователя>`

## Минимальный контейнер на busybox с ручной настройкой

если вам вдруг нечего делать, вы можете посмотреть папку small, в ней лежат скрипты для создания и запуска минимального контейнера с overlayfs корнем и busybox с dropbear.
