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
    echo -e "${BOLD}${WHITE}║          TITAN NODE MANAGER            ║${NC}"
    echo -e "${BOLD}${WHITE}╚════════════════════════════════════════╝${NC}\n"

    echo -e "${BOLD}${BLUE} Доступные действия:${NC}\n"
    echo -e "${WHITE}[${CYAN}1${WHITE}] ${GREEN}➜ ${WHITE}  Установка ноды${NC}"
    echo -e "${WHITE}[${CYAN}2${WHITE}] ${GREEN}➜ ${WHITE}  Запуск ноды${NC}"
    echo -e "${WHITE}[${CYAN}3${WHITE}] ${GREEN}➜ ${WHITE}  Просмотр логов${NC}"
    echo -e "${WHITE}[${CYAN}4${WHITE}] ${GREEN}➜ ${WHITE}  Установка нескольких нод${NC}"
    echo -e "${WHITE}[${CYAN}5${WHITE}] ${GREEN}➜ ${WHITE}  Перезапуск ноды${NC}"
    echo -e "${WHITE}[${CYAN}6${WHITE}] ${GREEN}➜ ${WHITE}  Остановка ноды${NC}"
    echo -e "${WHITE}[${CYAN}7${WHITE}] ${GREEN}➜ ${WHITE}  Удаление ноды${NC}"
    echo -e "${WHITE}[${CYAN}8${WHITE}] ${GREEN}➜ ${WHITE}  Выход${NC}\n"
}

# Функция для обработки CTRL+C
ctrl_c_handler() {
    echo -e "\n\n${YELLOW}Выход из просмотра логов...${NC}"
    sleep 1
    return
}

# Функция проверки занятости портов
check_ports() {
    info_message "Проверка занятости портов..."
    ports=(1234 55702 48710) # Список портов, которые использует нода Titan
    for port in "${ports[@]}"; do
        if [[ $(lsof -i :"$port" | wc -l) -gt 0 ]]; then
            error_message "Порт $port занят. Программа не сможет выполниться."
            return 1
        fi
    done
    success_message "Все порты свободны!"
    return 0
}

# Функция установки зависимостей
install_dependencies() {
    info_message "Установка необходимых пакетов..."
    sudo apt update && sudo apt install -y curl wget git nano jq screen lsb-release apt-transport-https ca-certificates gnupg2
    success_message "Зависимости установлены"
}

# Функция для установки Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        info_message "Установка Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        success_message "Docker успешно установлен!"
    else
        info_message "Docker уже установлен. Пропускаем установку."
    fi
}

# Функция для установки Docker Compose
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        info_message "Установка Docker Compose..."
        VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        success_message "Docker Compose успешно установлен!"
    else
        info_message "Docker Compose уже установлен. Пропускаем установку."
    fi
}

# Функция для установки ноды
install_node() {
    echo -e "\n${BOLD}${BLUE} Установка ноды Titan...${NC}\n"

    # Создание рабочей директории
    WORK_DIR="$HOME/nodes/titan"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # Проверка портов
    if ! check_ports; then
        error_message "Невозможно продолжить установку из-за занятых портов."
        print_menu
        return
    fi

    echo -e "${WHITE}[${CYAN}1/4${WHITE}] ${GREEN}➜ ${WHITE} Установка зависимостей...${NC}"
    install_dependencies
    install_docker
    install_docker_compose

    echo -e "${WHITE}[${CYAN}2/4${WHITE}] ${GREEN}➜ ${WHITE} Создание директории...${NC}"
    mkdir -p "$WORK_DIR/.titanedge"

    echo -e "${WHITE}[${CYAN}3/4${WHITE}] ${GREEN}➜ ${WHITE} Загрузка образа Docker...${NC}"
    docker pull nezha123/titan-edge

    echo -e "${WHITE}[${CYAN}4/4${WHITE}] ${GREEN}➜ ${WHITE}️ Настройка параметров...${NC}"
    echo -e "${YELLOW}Введите ваш Titan HASH:${NC}"
    read -p "HASH: " hash

    docker run --name titan --network=host -d --restart always -v "$WORK_DIR/.titanedge:/root/.titanedge" nezha123/titan-edge
    sleep 10
    docker run --rm -it -v "$WORK_DIR/.titanedge:/root/.titanedge" nezha123/titan-edge bind --hash="$hash" https://api-test1.container1.titannet.io/api/v2/device/binding

    echo -e "\n${PURPLE}═════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Нода успешно установлена и запущена!${NC}"
    echo -e "${PURPLE}═════════════════════════════════════════════${NC}\n"

    sleep 3
    print_menu
}

# Функция для запуска ноды
launch_node() {
    echo -e "\n${BOLD}${BLUE} Запуск ноды Titan...${NC}\n"

    # Проверка портов
    if ! check_ports; then
        error_message "Невозможно продолжить запуск из-за занятых портов."
        print_menu
        return
    fi

    echo -e "${YELLOW}Введите ваш Titan HASH:${NC}"
    read -p "HASH: " hash

    docker run --network=host -d --restart always -v "$HOME/nodes/titan/.titanedge:/root/.titanedge" nezha123/titan-edge
    sleep 10
    docker run --rm -it -v "$HOME/nodes/titan/.titanedge:/root/.titanedge" nezha123/titan-edge bind --hash="$hash" https://api-test1.container1.titannet.io/api/v2/device/binding
    success_message "Нода успешно запущена!"

    sleep 3
    print_menu
}

# Функция для просмотра логов
view_logs() {
    echo -e "\n${BOLD}${BLUE} Просмотр логов Titan...${NC}\n"

    # Установка обработчика CTRL+C
    trap ctrl_c_handler INT

    echo -e "${YELLOW}Для выхода из просмотра логов нажмите CTRL+C${NC}\n"
    docker logs -f titan

    # Удаление обработчика CTRL+C после выхода из логов
    trap - INT

    print_menu
}

# Функция для установки нескольких нод
install_multiple_nodes() {
    echo -e "\n${BOLD}${BLUE} Установка нескольких нод Titan...${NC}\n"

    # Создание рабочей директории
    WORK_DIR="$HOME/nodes/titan"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    # Проверка портов
    if ! check_ports; then
        error_message "Невозможно продолжить установку из-за занятых портов."
        print_menu
        return
    fi

    echo -e "${WHITE}[${CYAN}1/4${WHITE}] ${GREEN}➜ ${WHITE} Установка зависимостей...${NC}"
    install_dependencies
    install_docker
    install_docker_compose

    echo -e "${WHITE}[${CYAN}2/4${WHITE}] ${GREEN}➜ ${WHITE} Загрузка образа Docker...${NC}"
    docker pull nezha123/titan-edge

    echo -e "${WHITE}[${CYAN}3/4${WHITE}] ${GREEN}➜ ${WHITE}️ Введите ваш Titan HASH:${NC}"
    read -p "HASH: " hash

    echo -e "${WHITE}[${CYAN}4/4${WHITE}] ${GREEN}➜ ${WHITE}️ Установка нод...${NC}"
    start_port=1235
    container_count=5

    for ((i = 1; i <= container_count; i++)); do
        storage_path="$WORK_DIR/titan_storage_$i"
        sudo mkdir -p "$storage_path"
        sudo chmod -R 777 "$storage_path"

        docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan_$i" --net=host nezha123/titan-edge
        sleep 10

        docker exec "titan_$i" bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 50/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$start_port\"/' /root/.titanedge/config.toml && \
            echo 'Хранилище titan_$i настроено на 50 GB, порт: $start_port'"

        docker restart "titan_$i"
        sleep 30

        docker exec "titan_$i" bash -c "titan-edge bind --hash=$hash https://api-test1.container1.titannet.io/api/v2/device/binding"
        success_message "Нода titan_$i успешно установлена."

        start_port=$((start_port + 1))
    done

    echo -e "\n${PURPLE}═════════════════════════════════════════════${NC}"
    echo -e "${GREEN} Все ноды успешно установлены и запущены!${NC}"
    echo -e "${PURPLE}═════════════════════════════════════════════${NC}\n"

    sleep 3
    print_menu
}

# Функция для перезапуска ноды
restart_node() {
    echo -e "\n${BOLD}${BLUE} Перезапуск ноды Titan...${NC}\n"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker restart "$container_id"
    done
    success_message "Нода успешно перезапущена!"

    view_logs
}

# Функция для остановки ноды
stop_node() {
    echo -e "\n${BOLD}${BLUE} Остановка ноды Titan...${NC}\n"
    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker stop "$container_id"
    done
    success_message "Нода успешно остановлена!"

    sleep 3
    print_menu
}

# Функция для удаления ноды
remove_node() {
    echo -e "\n${BOLD}${RED}️ Удаление ноды Titan...${NC}\n"

    docker ps -a --filter "ancestor=nezha123/titan-edge" --format "{{.ID}}" | while read container_id; do
        docker stop "$container_id"
        docker rm "$container_id"
    done

    docker rmi nezha123/titan-edge
    sudo rm -rf "$HOME/nodes/titan"

    success_message "Нода успешно удалена!"

    sleep 3
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
            launch_node
            ;;
        3)
            view_logs
            ;;
        4)
            install_multiple_nodes
            ;;
        5)
            restart_node
            ;;
        6)
            stop_node
            ;;
        7)
            remove_node
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