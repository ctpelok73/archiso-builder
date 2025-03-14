#!/bin/bash
set -e

# Настраиваемые параметры
WORK_DIR="${HOME}/my-archiso"
ISO_NAME="archlinux-custom.iso"

# Создаем рабочую директорию
mkdir -p "${WORK_DIR}"

# Копируем конфигурацию Archiso
echo "Копируем конфигурацию Archiso..."
docker run --rm -v "${WORK_DIR}:/my-archiso" archlinux/archiso bash -c \
    "cp -r /usr/share/archiso/configs/releng /my-archiso/"

# Переходим в директорию с конфигурацией
cd "${WORK_DIR}/releng"

# Собираем ISO
echo "Собираем ISO..."
docker run --privileged --rm -v "${WORK_DIR}:/my-archiso" archlinux/archiso bash -c \
    "cd /my-archiso/releng && mkarchiso -v ."

# Проверяем, что ISO собран
if [ ! -f "${WORK_DIR}/out/"*".iso" ]; then
    echo "❌ Ошибка: ISO не найден!"
    exit 1
fi

echo "✅ Готово! ISO находится в: ${WORK_DIR}/out/"
ls -lh "${WORK_DIR}/out/"*.iso
