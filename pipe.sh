#!/bin/bash

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Определение рабочей директории
WORK_DIR="$HOME/nodes/pipe"

# Функция для отображения успешных сообщений
success_message() {
    echo -e "${GREEN}[✔] $1${NC}"
}

# Функция для отображения информационных сообщений
info_message() {
    echo -e "${CYAN}[ℹ️] $1${NC}"
}

# Функция для отображения ошибок
error_message() {
    echo -e "${RED}[✘] $1${NC}"
}

# Функция для отображения меню
print_menu() {
    clear

    echo -e "\n${BOLD}${WHITE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${WHITE}║          PIPE NODE MANAGER             ║${NC}"
    echo -e "${BOLD}${WHITE}╚════════════════════════════════════════╝${NC}\n"

    # Проверка статуса ноды
    if is_node_installed; then
        if systemctl is-active --quiet pipe-pop; then
            NODE_STATUS="${GREEN}Запущена${NC}"
        else
            NODE_STATUS="${RED}Остановлена${NC}"
        fi
    else
        NODE_STATUS="${YELLOW}Не установлена${NC}"
    fi

    echo -e "${BOLD}${BLUE} Статус ноды: $NODE_STATUS${NC}\n"

    echo -e "${BOLD}${BLUE} Доступные действия:${NC}\n"
    echo -e "${WHITE}[${CYAN}1${WHITE}] ${GREEN}➜ ${WHITE}  Установка ноды${NC}"
    echo -e "${WHITE}[${CYAN}2${WHITE}] ${GREEN}➜ ${WHITE}  Проверка статуса${NC}"
    echo -e "${WHITE}[${CYAN}3${WHITE}] ${GREEN}➜ ${WHITE}  Просмотр логов${NC}"
    echo -e "${WHITE}[${CYAN}4${WHITE}] ${GREEN}➜ ${WHITE}  Проверка поинтов${NC}"
    echo -e "${WHITE}[${CYAN}5${WHITE}] ${GREEN}➜ ${WHITE}  Обновление ноды${NC}"
    echo -e "${WHITE}[${CYAN}6${WHITE}] ${GREEN}➜ ${WHITE}  Удаление ноды${NC}"
    echo -e "${WHITE}[${CYAN}7${WHITE}] ${GREEN}➜ ${WHITE}  Просмотр рефрального кода${NC}"
    echo -e "${WHITE}[${CYAN}8${WHITE}] ${GREEN}➜ ${WHITE}  Выход${NC}\n"
}

# Функция для обработки CTRL+C
ctrl_c_handler() {
    echo -e "\n\n${YELLOW}Выход из просмотра логов...${NC}"
    sleep 1
    return
}

# Функция для проверки наличия curl и установки, если не установлен
install_dependencies() {
    info_message "Установка необходимых пакетов..."
    sudo apt update && sudo apt install -y curl wget lsof
    success_message "Зависимости установлены"
}

# Функция для проверки занятости портов
check_ports() {
    PORT=8003
    if lsof -i :$PORT > /dev/null 2>&1; then
        error_message "Порт $PORT уже занят другим процессом."
        info_message "Вы можете остановить процесс или изменить порт в конфигурации."
        read -p "Хотите продолжить установку? (y/n): " choice
        if [[ "$choice" != "y" ]]; then
            print_menu
            return 1
        fi
    else
        success_message "Порт $PORT свободен."
    fi
}

# Функция для проверки, установлена ли нода
is_node_installed() {
    if [ -f "$WORK_DIR/pop" ]; then
        return 0 # Нода установлена
    else
        return 1 # Нода не установлена
    fi
}

# Функция для включения автозапуска ноды
enable_autostart() {
    sudo systemctl enable pipe-pop
    success_message "Автозапуск ноды включен"
}

# Функция для установки ноды
install_node() {
    check_ports || return # Если порт занят и пользователь отказался, выходим

    echo -e "\n${BOLD}${BLUE} Установка ноды Pipe...${NC}\n"

    echo -e "${WHITE}[${CYAN}1/5${WHITE}] ${GREEN}➜ ${WHITE} Установка зависимостей...${NC}"
    install_dependencies

    echo -e "${WHITE}[${CYAN}2/5${WHITE}] ${GREEN}➜ ${WHITE} Создание директории...${NC}"
    mkdir -p $WORK_DIR/download_cache
    cd $WORK_DIR

    echo -e "${WHITE}[${CYAN}3/5${WHITE}] ${GREEN}➜ ${WHITE} Загрузка файлов...${NC}"
    wget https://dl.pipecdn.app/v0.2.8/pop
    chmod +x pop

    echo -e "${WHITE}[${CYAN}4/5${WHITE}] ${GREEN}➜ ${WHITE}️ Настройка параметров...${NC}"

    # Создание .env файла
    echo -e "${YELLOW}Введите количество оперативной памяти для ноды [Если хотите выделить 8 GB, то напишите 8]:${NC}"
    read -p "RAM: " ram
    echo -e "${YELLOW}Введите количество дискового пространства для ноды [Если хотите выделить 100 GB, то напишите 100]:${NC}"
    read -p "Max-disk: " max_disk
    echo -e "${YELLOW}Введите адрес вашего кошелька Solana:${NC}"
    read -p "pubKey: " pubKey

    # Создаем .env файл с введенными данными
    echo -e "ram=$ram\nmax-disk=$max_disk\ncache-dir=$WORK_DIR/download_cache\npubKey=$pubKey\n--signup-by-referral-route\nb0da2042257c9562" > $WORK_DIR/.env

    # Создание и запуск сервисного файла
    USERNAME=$(whoami)
    HOME_DIR=$(eval echo ~$USERNAME)
    sudo tee /etc/systemd/system/pipe-pop.service > /dev/null << EOF
[Unit]
Description=Pipe POP Node Service
After=network.target
Wants=network-online.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/pop \\
    --ram $ram \\
    --max-disk $max_disk \\
    --cache-dir $WORK_DIR/download_cache \\
    --pubKey $pubKey
Restart=always
RestartSec=5
LimitNOFILE=65536
LimitNPROC=4096
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dcdn-node

[Install]
WantedBy=multi-user.target
EOF

    # Перезагрузка и запуск сервиса
    sudo systemctl daemon-reload
    sleep 1
    enable_autostart
    sudo systemctl start pipe-pop

    echo -e "\n${PURPLE}═════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Нода успешно установлена и запущена!${NC}"
    echo -e "${PURPLE}═════════════════════════════════════════════${NC}\n"

    sleep 3
    print_menu
}

# Функция для проверки статуса
check_status() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${BLUE} Проверка статуса ноды...${NC}\n"
    cd $WORK_DIR
    ./pop --status
    cd ..

    sleep 10
    print_menu
}

# Функция для просмотра логов
view_logs() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${BLUE} Просмотр логов Pipe...${NC}\n"

    # Установка обработчика CTRL+C
    trap ctrl_c_handler INT

    echo -e "${YELLOW}Для выхода из просмотра логов нажмите CTRL+C${NC}\n"
    sudo journalctl -u pipe-pop -f --no-hostname -o cat

    # Удаление обработчика CTRL+C после выхода из логов
    trap - INT

    print_menu
}

# Функция для проверки поинтов
check_points() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${BLUE} Проверка поинтов ноды...${NC}\n"
    cd $WORK_DIR
    ./pop --points
    cd ..

    sleep 10
    print_menu
}

# Функция для обновления ноды
update_node() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${BLUE} Обновление ноды Pipe...${NC}\n"
    sudo systemctl stop pipe-pop
    rm -f $WORK_DIR/pop
    curl -o $WORK_DIR/pop https://dl.pipecdn.app/v0.2.8/pop
    chmod +x $WORK_DIR/pop
    $WORK_DIR/pop --refresh

    # Установка обработчика CTRL+C
    trap ctrl_c_handler INT

    echo -e "\n${YELLOW}Просмотр логов... Для выхода нажмите CTRL+C${NC}\n"
    sudo systemctl restart pipe-pop && sudo journalctl -u pipe-pop -f --no-hostname -o cat

    # Удаление обработчика CTRL+C после выхода из логов
    trap - INT

    print_menu
}

# Функция для удаления ноды
remove_node() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${RED}️ Удаление ноды Pipe...${NC}\n"

    echo -e "${WHITE}[${CYAN}1/3${WHITE}] ${GREEN}➜ ${WHITE} Остановка сервиса...${NC}"
    sudo systemctl stop pipe-pop
    sudo systemctl disable pipe-pop

    echo -e "${WHITE}[${CYAN}2/3${WHITE}] ${GREEN}➜ ${WHITE}️ Удаление файлов...${NC}"
    sudo rm -rf $WORK_DIR

    echo -e "${WHITE}[${CYAN}3/3${WHITE}] ${GREEN}➜ ${WHITE}️ Удаление сервисного файла...${NC}"
    sudo rm /etc/systemd/system/pipe-pop.service
    sudo systemctl daemon-reload

    echo -e "\n${GREEN} Нода успешно удалена!${NC}\n"
    sleep 3
    print_menu
}

# Функция для получения реф кода
check_ref() {
    if ! is_node_installed; then
        error_message "Нода не установлена. Пожалуйста, установите её сначала."
        sleep 2
        print_menu
        return
    fi

    echo -e "\n${BOLD}${BLUE} Ваш рефральный код...${NC}\n"
    cd $WORK_DIR
    ./pop --gen-referral-route
    cd ..

    sleep 10
    print_menu
}

# Основной цикл программы
while true; do
    print_menu
    echo -e "${BOLD}${BLUE} Введите номер действия [1-8]:${NC} "
    read -p "➜ " choice

    case $choice in
        1)
            install_node
            ;;
        2)
            check_status
            ;;
        3)
            view_logs
            ;;
        4)
            check_points
            ;;
        5)
            update_node
            ;;
        6)
            remove_node
            ;;
        7)
            check_ref
            ;;
        8)
            echo -e "\n${GREEN} До свидания!${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED} Ошибка: Неверный выбор! Пожалуйста, введите номер от 1 до 8.${NC}\n"
            sleep 2
            print_menu
            ;;
    esac
done