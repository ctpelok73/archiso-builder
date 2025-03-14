#!/bin/bash
set -e

# Настраиваемые параметры
USER_NAME="archuser"
WORK_DIR="${HOME}/my-archiso"
LOCALE="ru_RU.UTF-8"
KEYMAP="ru"

# Проверка наличия Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker не установлен!" >&2
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "❌ Docker недоступен. Проверьте:" >&2
        echo "1. Сервис запущен: sudo systemctl start docker" >&2
        echo "2. Вы в группе 'docker': sudo usermod -aG docker \$USER" >&2
        echo "3. Выполните 'newgrp docker' или перезапустите терминал" >&2
        return 1
    fi
}

# Проверка успешности сборки ISO
check_iso() {
    if [ ! -f "${WORK_DIR}/out/"*".iso" ]; then
        echo "❌ Ошибка: ISO не найден!" >&2
        exit 1
    fi
}

main() {
    # Проверка Docker
    if ! check_docker; then
        exit 1
    fi

    echo "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"
    echo "🚀 Начинаем сборку Arch Linux ISO"
    echo "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"

    # Очистка предыдущей сборки
    if [ -d "${WORK_DIR}" ]; then
        sudo rm -rf "${WORK_DIR}"
    fi
    mkdir -p "${WORK_DIR}"

    # Копирование конфигурации Archiso (устанавливаем все зависимости)
    docker run --rm -v "${WORK_DIR}:/my-archiso" archlinux bash -c \
        "pacman -Sy --noconfirm archiso base-devel squashfs-tools libisoburn && \
        cp -r /usr/share/archiso/configs/releng /my-archiso/"

    # Фикс прав
    sudo chown -R $USER:$USER "${WORK_DIR}"

    CONFIG_DIR="${WORK_DIR}/releng"
    cd "$CONFIG_DIR"

    # Список пакетов
    cat <<EOF > packages.x86_64
base
linux
linux-firmware
networkmanager
sudo
grub
plasma-meta
kde-applications-meta
pamac-gui
git
base-devel
firefox
telegram-desktop
htop
EOF

    # Локализация и раскладка
    echo "LANG=${LOCALE}" > airootfs/etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > airootfs/etc/vconsole.conf

    # Настройка пользователя
    mkdir -p airootfs/etc/sudoers.d
    echo "${USER_NAME} ALL=(ALL) ALL" > airootfs/etc/sudoers.d/10-user
    chmod 440 airootfs/etc/sudoers.d/10-user

    # Автовход в KDE Plasma
    mkdir -p airootfs/etc/sddm.conf.d
    echo -e "[Autologin]\nUser=${USER_NAME}\nSession=plasma.desktop" > airootfs/etc/sddm.conf.d/autologin.conf

    # Ярлык и инструкция на рабочем столе
    mkdir -p airootfs/home/${USER_NAME}/Desktop
    chown -R 1000:1000 airootfs/home/${USER_NAME}

    # Ярлык для установки
    cat <<EOF > airootfs/home/${USER_NAME}/Desktop/install-yandex.desktop
[Desktop Entry]
Version=1.0
Name=Установить Яндекс Браузер
Comment=Запустите этот скрипт для установки
Exec=konsole -e /home/${USER_NAME}/install-yandex-browser.sh
Icon=system-run
Terminal=false
Type=Application
EOF

    # Инструкция
    cat <<EOF > airootfs/home/${USER_NAME}/Desktop/README.txt
Добро пожаловать!

Чтобы установить Яндекс Браузер:
1. Дважды кликните на ярлык "Установить Яндекс Браузер".
2. Введите пароль пользователя, если потребуется.
3. Дождитесь завершения установки.

Скрипт удалится автоматически после выполнения.
EOF

    # Скрипт установки
    cat <<'EOF' > airootfs/home/${USER_NAME}/install-yandex-browser.sh
#!/bin/bash
echo "Устанавливаю Яндекс Браузер..."
git clone https://aur.archlinux.org/yandex-browser-beta.git
cd yandex-browser-beta
makepkg -si --noconfirm

# Удаление скрипта и ярлыков
rm -f ~/install-yandex-browser.sh ~/Desktop/install-yandex.desktop ~/Desktop/README.txt
EOF

    chmod +x airootfs/home/${USER_NAME}/install-yandex-browser.sh

    # Сборка ISO (используем явный путь к mkarchiso)
    echo "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"
    echo "🔨 Запуск сборки ISO..."
    docker run --privileged --rm -v "${WORK_DIR}:/my-archiso" archlinux bash -c \
        "cd /my-archiso/releng && /usr/bin/mkarchiso -v ."

    # Фикс прав после сборки
    sudo chown -R $USER:$USER "${WORK_DIR}"

    check_iso
    echo -e "\n✅ Готово! ISO находится в: ${WORK_DIR}/out/"
    ls -lh "${WORK_DIR}/out/"*.iso
}

main
