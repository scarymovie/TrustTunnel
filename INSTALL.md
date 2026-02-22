# Краткая инструкция по установке TrustTunnel

## 🚀 Быстрый старт

### Автоматическая установка с аргументами

```bash
# С указанием домена и IP
sudo ./setup.sh -d scary.ru -i 0.0.0.1

# Или только домен (IP запросится в процессе)
sudo ./setup.sh -d your-domain.com

# Интерактивный режим (все параметры вводятся вручную)
sudo ./setup.sh

# Показать справку
sudo ./setup.sh --help
```

---

## 📦 Установка сервера (Endpoint)

### Через setup.sh (рекомендуется)

```bash
sudo ./setup.sh -d your-domain.com -i 1.2.3.4
```

**В меню выберите:**
1. Установить сервер
2. Копировать конфиги
3. Сгенерировать сертификат (или 4 для Let's Encrypt)
4. Настроить systemd

### Вручную

```bash
# Установка
curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnel/refs/heads/master/scripts/install.sh | sh -s -

# Настройка
cd /opt/trusttunnel/
sudo ./setup_wizard

# Запуск
sudo systemctl start trusttunnel
```

---

## 💻 Установка клиента

### Через setup.sh

```bash
sudo ./setup.sh -d your-domain.com -i 1.2.3.4
```

**В меню выберите:**
6. Установить клиента
7. Копировать клиентский конфиг

### Вручную

**Linux / macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/TrustTunnel/TrustTunnelClient/refs/heads/master/scripts/install.sh | sh -s -
```

**Windows:**
Скачайте релиз с https://github.com/TrustTunnel/TrustTunnelClient/releases

---

## ⚙️ Настройка

### Конфигурационные файлы

| Файл | Назначение |
|------|-----------|
| `vpn.toml` | Настройки сервера |
| `hosts.toml` | TLS сертификаты |
| `credentials.toml` | Пользователи |
| `rules.toml` | Правила фильтрации |
| `trusttunnel_client.toml` | Клиент |

### Изменение паролей

```bash
nano /opt/trusttunnel/credentials.toml
```

```toml
[[client]]
username = "admin"
password = "Ваш_Очень_Сложный_Пароль!"
```

### Экспорт конфигурации клиента

```bash
cd /opt/trusttunnel/
./trusttunnel_endpoint vpn.toml hosts.toml -c admin -a 1.2.3.4
```

---

## 🔧 Управление сервисом

```bash
# Статус
systemctl status trusttunnel

# Перезапуск
systemctl restart trusttunnel

# Остановка
systemctl stop trusttunnel

# Автозапуск
systemctl enable trusttunnel

# Логи
journalctl -u trusttunnel -f
```

---

## 📚 Документация

- [Настройка с аргументами](SETUP_ARGS_GUIDE.md)
- [Полная документация](README.md)
- [Руководство по конфигам](CONFIG_GUIDE.md)
- [GUI клиент](https://github.com/TrustTunnel/TrustTunnelFlutterClient)
- [CLI клиент](https://github.com/TrustTunnel/TrustTunnelClient)
