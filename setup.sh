#!/bin/bash

# TrustTunnel Setup Script
# Автоматическая установка и настройка TrustTunnel сервера и клиента
#
# Использование:
#   sudo ./setup.sh                          # интерактивный режим
#   sudo ./setup.sh -d domain.com -i 1.2.3.4 # с аргументами
#
# Аргументы:
#   -d, --domain <domain>   Домен сервера (например: scary.ru)
#   -i, --ip <ip>           IP адрес сервера (например: 0.0.0.1)
#   -h, --help              Показать справку

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Пути по умолчанию
ENDPOINT_DIR="/opt/trusttunnel"
CLIENT_DIR="/opt/trusttunnel_client"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# Значения по умолчанию (будут переопределены аргументами или вводом)
SERVER_DOMAIN=""
SERVER_IP=""

# Показать справку
show_help() {
    echo "TrustTunnel Setup Script"
    echo ""
    echo "Использование:"
    echo "  sudo ./setup.sh [OPTIONS]"
    echo ""
    echo "Аргументы:"
    echo "  -d, --domain <domain>   Домен сервера (обязательно для авто-режима)"
    echo "  -i, --ip <ip>           IP адрес сервера (обязательно для авто-режима)"
    echo "  -h, --help              Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  sudo ./setup.sh"
    echo "  sudo ./setup.sh -d scary.ru -i 0.0.0.1"
    echo ""
}

# Парсинг аргументов
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                SERVER_DOMAIN="$2"
                shift 2
                ;;
            -i|--ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Неизвестный аргумент: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Запустите скрипт от имени root (sudo ./setup.sh)"
        exit 1
    fi
}

# Проверка ОС
check_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        log_error "Неподдерживаемая ОС: $OSTYPE"
        exit 1
    fi
    log_info "Обнаружена ОС: $OS"
}

# Проверка наличия конфигов
check_configs() {
    if [ -d "$CONFIG_DIR" ]; then
        log_info "Директория с конфигами: $CONFIG_DIR"
    else
        log_warn "Директория configs не найдена"
    fi
}

# Установка сервера (Endpoint)
install_endpoint() {
    log_header "Установка TrustTunnel сервера"
    
    curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnel/refs/heads/master/scripts/install.sh | sh -s -
    
    if [ -d "$ENDPOINT_DIR" ]; then
        log_info "Сервер установлен в $ENDPOINT_DIR"
    else
        log_error "Ошибка установки сервера"
        exit 1
    fi
}

# Копирование конфигов
copy_configs() {
    log_header "Копирование конфигурационных файлов"

    if [ ! -d "$CONFIG_DIR" ]; then
        log_error "Директория configs не найдена: $CONFIG_DIR"
        return 1
    fi

    cd "$ENDPOINT_DIR"

    # Копирование файлов с подстановкой домена и IP
    for file in vpn.toml hosts.toml credentials.toml rules.toml; do
        if [ -f "$CONFIG_DIR/$file" ]; then
            # Подстановка значений для hosts.toml и trusttunnel_client.toml
            if [ "$file" = "hosts.toml" ]; then
                # Используем | как разделитель вместо / для избежания конфликтов
                sed -e "s|your-domain.com|$SERVER_DOMAIN|g" "$CONFIG_DIR/$file" > "$file"
                log_info "Скопирован $file (домен: $SERVER_DOMAIN)"
            elif [ "$file" = "trusttunnel_client.toml" ]; then
                # Экранируем точки в IP для sed
                ESCAPED_IP=$(echo "$SERVER_IP" | sed 's/\./\\./g')
                sed -e "s|your-domain.com|$SERVER_DOMAIN|g" \
                    -e "s|1\\.2\\.3\\.4|$ESCAPED_IP|g" "$CONFIG_DIR/$file" > "$file"
                log_info "Скопирован $file (домен: $SERVER_DOMAIN, IP: $SERVER_IP)"
            else
                cp "$CONFIG_DIR/$file" .
                log_info "Скопирован $file"
            fi
        fi
    done

    # Создание директории для сертификатов
    mkdir -p certs
    log_info "Создана директория certs/"

    log_info "Конфигурационные файлы скопированы в $ENDPOINT_DIR"
    log_warn "Проверьте конфиги при необходимости!"
}

# Генерация самоподписанного сертификата
generate_selfsigned_cert() {
    log_header "Генерация самоподписанного сертификата"

    cd "$ENDPOINT_DIR"

    log_info "Генерация сертификата для домена: $SERVER_DOMAIN"
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout certs/key.pem \
        -out certs/cert.pem \
        -subj "/CN=$SERVER_DOMAIN" \
        -addext "subjectAltName=DNS:$SERVER_DOMAIN,DNS:*.$SERVER_DOMAIN"

    if [ $? -eq 0 ]; then
        log_info "Сертификат сгенерирован:"
        echo "  - certs/cert.pem"
        echo "  - certs/key.pem"
        log_warn "Для использования в Flutter клиенте нужен доверенный сертификат (Let's Encrypt)"
    else
        log_error "Ошибка генерации сертификата"
        return 1
    fi
}

# Настройка сервера через wizard
configure_endpoint_wizard() {
    log_header "Настройка сервера (мастер)"
    
    cd "$ENDPOINT_DIR"
    
    if [ ! -f "./setup_wizard" ]; then
        log_error "setup_wizard не найден"
        exit 1
    fi
    
    log_warn "Запуск интерактивного мастера настройки..."
    sudo ./setup_wizard
    log_info "Настройка сервера завершена"
}

# Настройка systemd сервиса
setup_systemd() {
    log_header "Настройка systemd сервиса"
    
    cd "$ENDPOINT_DIR"
    
    if [ ! -f "trusttunnel.service.template" ]; then
        log_warn "trusttunnel.service.template не найден"
        return 1
    fi
    
    cp trusttunnel.service.template /etc/systemd/system/trusttunnel.service
    systemctl daemon-reload
    systemctl enable --now trusttunnel
    
    log_info "Systemd сервис настроен и запущен"
    systemctl status trusttunnel --no-pager
}

# Установка клиента
install_client() {
    log_header "Установка TrustTunnel клиента"
    
    curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/refs/heads/master/scripts/install.sh | sh -s -
    
    if [ -d "$CLIENT_DIR" ]; then
        log_info "Клиент установлен в $CLIENT_DIR"
    else
        log_error "Ошибка установки клиента"
        exit 1
    fi
}

# Настройка клиента
configure_client() {
    log_header "Настройка клиента"
    
    cd "$CLIENT_DIR"
    
    if [ ! -f "./setup_wizard" ]; then
        log_error "setup_wizard не найден"
        exit 1
    fi
    
    read -p "Введите путь к конфигурации сервера: " endpoint_config
    
    if [ -f "$endpoint_config" ]; then
        ./setup_wizard --mode non-interactive \
             --endpoint_config "$endpoint_config" \
             --settings trusttunnel_client.toml
        log_info "Настройка клиента завершена"
    else
        log_error "Файл не найден: $endpoint_config"
        exit 1
    fi
}

# Копирование клиентского конфига
copy_client_config() {
    log_header "Копирование клиентского конфига"

    if [ ! -f "$CONFIG_DIR/trusttunnel_client.toml" ]; then
        log_error "trusttunnel_client.toml не найден в $CONFIG_DIR"
        return 1
    fi

    cd "$CLIENT_DIR"
    
    # Копирование с подстановкой значений
    # Экранируем точки в IP для sed
    ESCAPED_IP=$(echo "$SERVER_IP" | sed 's/\./\\./g')
    sed -e "s|your-domain.com|$SERVER_DOMAIN|g" \
        -e "s|1\\.2\\.3\\.4|$ESCAPED_IP|g" \
        "$CONFIG_DIR/trusttunnel_client.toml" > trusttunnel_client.toml

    log_info "Конфиг скопирован в $CLIENT_DIR/trusttunnel_client.toml"
    log_info "Домен: $SERVER_DOMAIN, IP: $SERVER_IP"
    log_warn "Отредактируйте пароль перед запуском!"
}

# Экспорт конфигурации клиента
export_client_config() {
    log_header "Экспорт конфигурации для клиента"

    cd "$ENDPOINT_DIR"

    read -p "Имя клиента (из credentials.toml): " client_name
    log_info "Используется IP: $SERVER_IP, домен: $SERVER_DOMAIN"
    read -p "Использовать IP по умолчанию ($SERVER_IP)? (y/n): " use_ip
    use_ip=${use_ip:-y}
    
    if [[ $use_ip =~ ^[Yy]$ ]]; then
        public_ip="$SERVER_IP"
    else
        read -p "Публичный IP сервера: " public_ip
    fi
    
    read -p "Порт (по умолчанию: 443): " port
    port=${port:-443}

    if [ -f "./trusttunnel_endpoint" ]; then
        ./trusttunnel_endpoint vpn.toml hosts.toml -c "$client_name" -a "${public_ip}:${port}"
        log_info "Конфигурация экспортирована"
    else
        log_error "trusttunnel_endpoint не найден"
    fi
}

# Проверка статуса
check_status() {
    log_header "Статус сервисов"
    
    echo -e "\n${GREEN}Сервер (Endpoint):${NC}"
    if systemctl is-active --quiet trusttunnel 2>/dev/null; then
        echo "  Статус: ✓ Активен"
        systemctl status trusttunnel --no-pager | head -5
    else
        echo "  Статус: ✗ Не активен"
    fi
    
    echo -e "\n${GREEN}Клиент:${NC}"
    if pgrep -x "trusttunnel_client" > /dev/null; then
        echo "  Статус: ✓ Работает"
    else
        echo "  Статус: ✗ Не работает"
    fi
}

# Главное меню
show_menu() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   TrustTunnel Setup Script               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  1. Установить сервер (Endpoint)"
    echo "  2. Копировать конфиги в /opt/trusttunnel"
    echo "  3. Сгенерировать самоподписанный сертификат"
    echo "  4. Настроить сервер (мастер)"
    echo "  5. Настроить systemd сервис"
    echo "  ----------------------------------------"
    echo "  6. Установить клиента"
    echo "  7. Копировать клиентский конфиг"
    echo "  8. Настроить клиента"
    echo "  ----------------------------------------"
    echo "  9. Экспортировать конфигурацию клиента"
    echo "  10. Проверить статус сервисов"
    echo "  ----------------------------------------"
    echo "  0. Выйти"
    echo ""
}

# Запрос домена и IP если не указаны
prompt_server_details() {
    if [ -z "$SERVER_DOMAIN" ]; then
        read -p "Введите домен сервера (например: scary.ru): " SERVER_DOMAIN
    fi
    
    if [ -z "$SERVER_IP" ]; then
        read -p "Введите IP адрес сервера (например: 0.0.0.1): " SERVER_IP
    fi
    
    # Проверка заполненности
    if [ -z "$SERVER_DOMAIN" ] || [ -z "$SERVER_IP" ]; then
        log_error "Домен и IP должны быть указаны"
        exit 1
    fi
    
    log_info "Используется домен: $SERVER_DOMAIN, IP: $SERVER_IP"
}

# Основная функция
main() {
    parse_args "$@"
    check_root
    check_os
    check_configs
    prompt_server_details

    log_header "Добро пожаловать в TrustTunnel Setup Script"
    
    while true; do
        show_menu
        read -p "Выберите действие (0-10): " choice
        
        case $choice in
            1) install_endpoint ;;
            2) copy_configs ;;
            3) generate_selfsigned_cert ;;
            4) configure_endpoint_wizard ;;
            5) setup_systemd ;;
            6) install_client ;;
            7) copy_client_config ;;
            8) configure_client ;;
            9) export_client_config ;;
            10) check_status ;;
            0)
                log_info "Выход..."
                exit 0
                ;;
            *)
                log_error "Неверный выбор (0-10)"
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск
main "$@"
