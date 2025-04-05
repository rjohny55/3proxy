# Используем легковесный базовый образ Debian для сборки
FROM debian:stable-slim AS builder

# Устанавливаем версию 3proxy как аргумент сборки
ARG version=0.9.4

# Устанавливаем необходимые пакеты для сборки и скачивания
# Добавляем libc6-dev для заголовочных файлов C
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    tar \
    gcc \
    make \
    git \
    ca-certificates \
    libc6-dev \
 && rm -rf /var/lib/apt/lists/*

# Устанавливаем рабочую директорию для сборки
WORKDIR /tmp

# Скачиваем, распаковываем, компилируем 3proxy и очищаем за собой
RUN wget --no-check-certificate -O 3proxy-${version}.tar.gz https://github.com/z3APA3A/3proxy/archive/${version}.tar.gz \
 && tar xzf 3proxy-${version}.tar.gz \
 && cd 3proxy-${version} \
 && make -f Makefile.Linux \
 # Исправляем путь к скомпилированному бинарному файлу (bin/3proxy)
 && mv bin/3proxy /usr/local/bin/3proxy \
 && cd /tmp \
 && rm -rf 3proxy-${version} 3proxy-${version}.tar.gz

# --- Создаем финальный легковесный образ ---
FROM debian:stable-slim

# Копируем скомпилированный бинарный файл 3proxy из образа сборщика
COPY --from=builder /usr/local/bin/3proxy /usr/local/bin/3proxy

# Устанавливаем только необходимые для работы пакеты (wget/git нужны для скачивания конфигов при старте, если нужно)
# Если конфиги будут подключаться через volumes, wget и git в финальном образе можно не ставить.
# Оставляем их для совместимости с изначальной идеей скачивания конфигов при сборке.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Создаем необходимые директории для конфигов и логов
RUN mkdir -p /etc/3proxy/ /var/log/3proxy/

# Скачиваем файлы конфигурации и аутентификации и устанавливаем права
# ЗАМЕЧАНИЕ: Лучше подключать эти файлы через volumes/bind mounts при запуске контейнера (как в docker-compose),
# но оставляем этот шаг для соответствия изначальному скрипту и для простоты базового образа.
RUN wget --no-check-certificate https://github.com/SnoyIatk/3proxy/raw/master/3proxy.cfg -O /etc/3proxy/3proxy.cfg \
 && chmod 600 /etc/3proxy/3proxy.cfg \
 && wget --no-check-certificate https://github.com/SnoyIatk/3proxy/raw/master/.proxyauth -O /etc/3proxy/.proxyauth \
 && chmod 600 /etc/3proxy/.proxyauth

# Создаем непривилегированного пользователя для запуска 3proxy из соображений безопасности
RUN useradd --system --shell /usr/sbin/nologin --home-dir /etc/3proxy proxyuser \
 # Устанавливаем владельца для папок конфигов и логов
 && chown -R proxyuser:proxyuser /etc/3proxy /var/log/3proxy

# Переключаемся на созданного непривилегированного пользователя
USER proxyuser

# Открываем стандартные порты для 3proxy (убедитесь, что они соответствуют вашему 3proxy.cfg)
EXPOSE 3128 1080

# Устанавливаем рабочую директорию для запуска команды CMD
WORKDIR /etc/3proxy

# Команда для запуска 3proxy в foreground режиме при старте контейнера
CMD ["/usr/local/bin/3proxy", "/etc/3proxy/3proxy.cfg"]
