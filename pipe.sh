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

# Проверка наличия curl и установка, если не установлен
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

# Функция для отображения успешных сообщений
success_message() {
    echo -e "${GREEN}[] $1${NC}"
}

# Функция для отображения информационных сообщений
info_message() {
    echo -e "${CYAN}[️] $1${NC}"
}

# Функция для отображения ошибок
error_message() {
    echo -e "${RED}[] $1${NC}"
}

# Функция для отображения меню
print_menu() {
    clear

    echo -e "\n${BOLD}${WHITE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${WHITE}║          PIPE NODE MANAGER            ║${NC}"
    echo -e "${BOLD}${WHITE}╚════════════════════════════════════════╝${NC}\n"

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

# Функция установки зависимостей
install_dependencies() {
    info_message "Установка необходимых пакетов..."
    sudo apt update && sudo apt install -y curl wget
    success_message "Зависимости установлены"
}

# Функция для установки ноды
install_node() {
    echo -e "\n${BOLD}${BLUE} Установка ноды Pipe...${NC}\n"

    echo -e "${WHITE}[${CYAN}1/5${WHITE}] ${GREEN}➜ ${WHITE} Установка зависимостей...${NC}"
    install_dependencies

    echo -e "${WHITE}[${CYAN}2/5${WHITE}] ${GREEN}➜ ${WHITE} Создание директории...${NC}"
    mkdir -p ~/pipenetwork/download_cache
    cd ~/pipenetwork

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
    echo -e "ram=$ram\nmax-disk=$max_disk\ncache-dir=$HOME/pipenetwork/download_cache\npubKey=$pubKey\n--signup-by-referral-route\nb0da2042257c9562" > $HOME/pipenetwork/.env

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
WorkingDirectory=$HOME_DIR/pipenetwork
ExecStart=$HOME_DIR/pipenetwork/pop \\
    --ram $ram \\
    --max-disk $max_disk \\
    --cache-dir $HOME_DIR/pipenetwork/download_cache \\
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
    sudo systemctl enable pipe-pop
    sudo systemctl start pipe-pop

    echo -e "\n${PURPLE}═════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Нода успешно установлена и запущена!${NC}"
    echo -e "${PURPLE}═════════════════════════════════════════════${NC}\n"

    sleep 3
    print_menu
}

# Функция для проверки статуса
check_status() {
    echo -e "\n${BOLD}${BLUE} Проверка статуса ноды...${NC}\n"
    cd ~/pipenetwork
    ./pop --status
    cd ..

    sleep 10
    print_menu
}

# Функция для просмотра логов
view_logs() {
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
    echo -e "\n${BOLD}${BLUE} Проверка поинтов ноды...${NC}\n"
    cd ~/pipenetwork
    ./pop --points
    cd ..

    sleep 10
    print_menu
}

# Функция для обновления ноды
update_node() {
    echo -e "\n${BOLD}${BLUE} Обновление ноды Pipe...${NC}\n"
    sudo systemctl stop pipe-pop
    rm -f $HOME/pipenetwork/pop
    curl -o $HOME/pipenetwork/pop https://dl.pipecdn.app/v0.2.8/pop
    chmod +x $HOME/pipenetwork/pop
    $HOME/pipenetwork/pop --refresh

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
    echo -e "\n${BOLD}${RED}️ Удаление ноды Pipe...${NC}\n"

    echo -e "${WHITE}[${CYAN}1/3${WHITE}] ${GREEN}➜ ${WHITE} Остановка сервиса...${NC}"
    sudo systemctl stop pipe-pop
    sudo systemctl disable pipe-pop

    echo -e "${WHITE}[${CYAN}2/3${WHITE}] ${GREEN}➜ ${WHITE}️ Удаление файлов...${NC}"
    sudo rm -rf ~/pipenetwork

    echo -e "${WHITE}[${CYAN}3/3${WHITE}] ${GREEN}➜ ${WHITE}️ Удаление сервисного файла...${NC}"
    sudo rm /etc/systemd/system/pipe-pop.service
    sudo systemctl daemon-reload

    echo -e "\n${GREEN} Нода успешно удалена!${NC}\n"
    sleep 3
    print_menu
}

# Функция для получения реф кода
check_ref() {
    echo -e "\n${BOLD}${BLUE} Ваш рефральный код...${NC}\n"
    cd ~/pipenetwork
    ./pop --gen-referral-route
    cd ..

    sleep 10
    print_menu
}

# Основной цикл программы
while true; do
    print_menu
    echo -e "${BOLD}${BLUE} Введите номер действия [1-7]:${NC} "
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
            echo -e "\n${RED} Ошибка: Неверный выбор! Пожалуйста, введите номер от 1 до 7.${NC}\n"
            sleep 2
            print_menu
            ;;
    esac
done