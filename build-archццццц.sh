#!/bin/bash
set -e

# Настраиваемые параметры
USER_NAME="archuser"
WORK_DIR="${HOME}/my-archiso"
LOCALE="ru_RU.UTF-8"
KEYMAP="ru"

# Функция для логирования
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Проверка наличия Docker
check_docker() {
    log "Проверка наличия Docker..."
    if ! command -v docker &> /dev/null; then
        log "❌ Docker не установлен!"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log "❌ Docker недоступен. Проверьте:"
        log "1. Сервис запущен: sudo systemctl start docker"
        log "2. Вы в группе 'docker': sudo usermod -aG docker \$USER"
        log "3. Выполните 'newgrp docker' или перезапустите терминал"
        return 1
    fi
    log "✅ Docker доступен."
}

# Проверка успешности сборки ISO
check_iso() {
    log "Проверка наличия ISO..."
    if [ ! -f "${WORK_DIR}/out/"*".iso" ]; then
        log "❌ Ошибка: ISO не найден!"
        exit 1
    fi
    log "✅ ISO успешно собран."
}

main() {
    log "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"
    log "🚀 Начинаем сборку Arch Linux ISO"
    log "▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬"

    # Проверка Docker
    if ! check_docker; then
        exit 1
    fi

    # Очистка предыдущей сборки
    if [ -d "${WORK_DIR}" ]; then
        log "Очистка предыдущей сборки..."
        sudo rm -rf "${WORK_DIR}"
    fi
    mkdir -p "${WORK_DIR}"
    log "Рабочая директория создана: ${WORK_DIR}"

    # Копирование конфигурации Archiso
    log "Копирование конфигурации Archiso..."
    docker run --rm -v "${WORK_DIR}:/my-archiso" archlinux bash -c \
        "pacman -Sy --noconfirm archiso base-devel squashfs-tools libisoburn && \
        cp -r /usr/share/archiso/configs/releng /my-archiso/"
    log "Конфигурация Archiso скопирована."

    # Фикс прав
    log "Изменение прав доступа на рабочую директорию..."
    sudo chown -R $USER:$USER "${WORK_DIR}"
    log "Права доступа изменены."

    CONFIG_DIR="${WORK_DIR}/releng"
    cd "$CONFIG_DIR"

    # Список пакетов
    log "Создание списка пакетов..."
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
    log "Список пакетов создан."

    # Локализация и раскладка
    log "Настройка локализации и раскладки..."
    echo "LANG=${LOCALE}" > airootfs/etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > airootfs/etc/vconsole.conf
    log "Локализация и раскладка настроены."

    # Настройка пользователя
    log "Настройка пользователя..."
    mkdir -p airootfs/etc/sudoers.d
    echo "${USER_NAME} ALL=(ALL) ALL" > airootfs/etc/sudoers.d/10-user
    chmod 440 airootfs/etc/sudoers.d/10-user
    log "Пользователь настроен."

    # Автовход в KDE Plasma
    log "Настройка автовхода в KDE Plasma..."
    mkdir -p airootfs/etc/sddm.conf.d
    echo -e "[Autologin]\nUser=${USER_NAME}\nSession=plasma.desktop" > airootfs/etc/sddm.conf.d/autologin.conf
    log "Автовход настроен."

    # Ярлык и инструкция на рабочем столе
    log "Создание ярлыков и инструкций на рабочем столе..."
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
    log "Ярлыки и инструкции созданы."

    # Скрипт установки
    log "Создание скрипта установки..."
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
    log "Скрипт установки создан."

    # Сборка ISO
    log "Запуск сборки ISO..."
    docker run --privileged --rm -v "${WORK_DIR}:/my-archiso" archlinux bash -c \
        "cd /my-archiso/releng && /usr/bin/mkarchiso -v ."
    log "Сборка ISO завершена."

    # Фикс прав после сборки
    log "Изменение прав доступа после сборки..."
    sudo chown -R $USER:$USER "${WORK_DIR}"
    log "Права доступа изменены."

    check_iso
    log "✅ Готово! ISO находится в: ${WORK_DIR}/out/"
    ls -lh "${WORK_DIR}/out/"*.iso
}

main
