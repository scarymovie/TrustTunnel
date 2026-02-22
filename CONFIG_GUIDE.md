# Руководство по настройке конфигурационных файлов TrustTunnel

## 📁 Структура файлов

```
configs/
├── vpn.toml                 # Настройки сервера
├── hosts.toml               # TLS сертификаты
├── credentials.toml         # Пользователи
├── rules.toml               # Правила фильтрации
└── trusttunnel_client.toml  # Клиент
```

---

## 🖥️ Настройка сервера (Endpoint)

### 1. vpn.toml

**Обязательные поля для изменения:**

| Поле | Значение по умолчанию | Что изменить |
|------|----------------------|--------------|
| `listen_address` | `"0.0.0.0:443"` | Порт если 443 занят |
| `credentials_file` | `"credentials.toml"` | Путь если отличается |

**Пример минимальной конфигурации:**
```toml
listen_address = "0.0.0.0:443"
ipv6_available = true
credentials_file = "credentials.toml"

[listen_protocols.http1]
[listen_protocols.http2]
[listen_protocols.quic]

[forward_protocol]
direct = {}
```

---

### 2. hosts.toml

**Что нужно изменить:**

1. Замените `vpn.example.com` на ваш домен
2. Укажите пути к сертификатам

**Для самоподписанного сертификата (тестирование):**
```toml
[[main_hosts]]
hostname = "vpn.myserver.local"
cert_chain_path = "certs/selfsigned.crt"
private_key_path = "certs/selfsigned.key"
```

**Для Let's Encrypt (продакшен):**
```toml
[[main_hosts]]
hostname = "vpn.yourdomain.com"
cert_chain_path = "/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
private_key_path = "/etc/letsencrypt/live/yourdomain.com/privkey.pem"
```

---

### 3. credentials.toml

**Добавьте пользователей:**

```toml
[[client]]
username = "ivan"
password = "SuperSecure#Password123!"

[[client]]
username = "maria"
password = "AnotherSecure#Pass456!"
```

**Рекомендации:**
- Минимум 16 символов
- Используйте генератор паролей
- Один пользователь на устройство

---

### 4. rules.toml

**Минимальная конфигурация (разрешить всё):**
```toml
# Пустой файл или закомментированные правила
# Все соединения разрешены по умолчанию
```

**Заблокировать частные IP:**
```toml
[[rule]]
cidr = "192.168.0.0/16"
action = "deny"

[[rule]]
cidr = "10.0.0.0/8"
action = "deny"
```

---

## 📱 Настройка клиента

### trusttunnel_client.toml

**Обязательные поля:**

```toml
[endpoint]
hostname = "vpn.yourdomain.com"        # Ваш домен
addresses = ["203.0.113.50:443"]       # IP сервера
username = "ivan"                       # Из credentials.toml
password = "SuperSecure#Password123!"   # Из credentials.toml
```

**Режимы работы:**

| Режим | Описание | Когда использовать |
|-------|----------|-------------------|
| `general` | Весь трафик через VPN | Стандартное использование |
| `selective` | Только exclusions через VPN | Обход блокировок отдельных сайтов |

**Пример для обхода блокировок:**
```toml
vpn_mode = "selective"
exclusions = [
    "youtube.com",
    "*.youtube.com",
    "twitter.com",
]
```

---

## 🔐 Получение сертификатов

### Вариант 1: Let's Encrypt (рекомендуется)

**Требования:**
- Публичный домен
- Порт 80 открыт

**Через setup_wizard:**
```bash
cd /opt/trusttunnel/
sudo ./setup_wizard
# Выбрать "Issue a Let's Encrypt certificate"
```

### Вариант 2: Самоподписанный (тестирование)

```bash
cd /opt/trusttunnel/
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/selfsigned.key \
  -out certs/selfsigned.crt \
  -subj "/CN=vpn.myserver.local"
```

### Вариант 3: Certbot

```bash
# Установка
apt install certbot

# Получение сертификата
certbot certonly --standalone -d vpn.yourdomain.com
```

---

## 🚀 Быстрый старт

### 1. Минимальная настройка сервера

**Для scary.ru:**
```bash
cd /opt/trusttunnel/

# Создать директорию для сертификатов
mkdir -p certs

# Сгенерировать самоподписанный сертификат
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/key.pem \
  -out certs/cert.pem \
  -subj "/CN=scary.ru" \
  -addext "subjectAltName=DNS:scary.ru,DNS:*.scary.ru"

# Редактировать credentials.toml
nano credentials.toml

# Запустить сервер
./trusttunnel_endpoint vpn.toml hosts.toml
```

### 2. Экспорт конфигурации клиента

**Для scary.ru:**
```bash
./trusttunnel_endpoint vpn.toml hosts.toml \
  -c admin \
  -a 0.0.0.1
```

### 3. Запуск клиента

```bash
cd /opt/trusttunnel_client/
sudo ./trusttunnel_client -c trusttunnel_client.toml
```

---

## 🔧 Проверка конфигурации

### Проверка сервера

```bash
# Проверка синтаксиса TOML
cd /opt/trusttunnel/
./trusttunnel_endpoint vpn.toml hosts.toml --check

# Запуск в режиме отладки
./trusttunnel_endpoint vpn.toml hosts.toml -l debug
```

### Проверка клиента

```bash
# Тест подключения
./trusttunnel_client -c trusttunnel_client.toml --test

# Режим отладки
./trusttunnel_client -c trusttunnel_client.toml -l debug
```

---

## ❓ Частые проблемы

### Сервер не запускается

**Проблема:** Порт 443 занят
```toml
# Решение: изменить порт
listen_address = "0.0.0.0:8443"
```

### Клиент не подключается

**Проблема:** Сертификат не доверяется
```toml
# Временно (только для тестирования!)
[endpoint]
skip_verification = true
```

**Проблема:** Неправильный домен
```toml
# Проверьте что hostname совпадает с сертификатом
[endpoint]
hostname = "vpn.yourdomain.com"  # Должно совпадать с CN сертификата
```

### Медленное соединение

**Решение:** Использовать HTTP/3 (QUIC)
```toml
[endpoint]
upstream_protocol = "http3"
```

---

## 📚 Дополнительные ресурсы

- [Официальная документация](https://github.com/TrustTunnel/TrustTunnel/blob/master/CONFIGURATION.md)
- [CLI клиент](https://github.com/TrustTunnel/TrustTunnelClient)
- [Flutter клиент](https://github.com/TrustTunnel/TrustTunnelFlutterClient)
