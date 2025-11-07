# Monitoring_Effective_Mobile
Описание: bash скрипт + systemd таймер

Запускается при загрузке системы
Выполняется каждую минуту
Проверяет, жив ли процесс test
Отправляет HTTPS‑запрос на https://test.com/monitoring/test/api (только если процесс запущен) (из проблем домен в продаже)
Логирует в /var/log/monitoring.log:
перезапуск процесса
недоступность сервера мониторинга 'https://test.com/monitoring/test/api'
Настройка и работа: ОС Debian 13.1.0 Для тестового задания все действия проводил под root(не рекомендуется)

Вывод: tail -f /var/log/monitoring.log

1. Установка и настройка

1.1 Создадим пользователя
sudo useradd -r -s /bin/false -d /var/lib/monitor monitor
sudo groupadd monitor 2>/dev/null || true

1.2 Создадим папки
sudo mkdir -p /var/lib/monitor
sudo chown monitor:monitor /var/lib/monitor

sudo touch /var/log/monitoring.log
sudo chown monitor:monitor /var/log/monitoring.log
sudo chmod 644 /var/log/monitoring.log

sudo touch /var/run/monitor-test.state
sudo chown monitor:monitor /var/run/monitor-test.state
sudo chmod 644 /var/run/monitor-test.state

1.3 Скопируем файлы в директории
sudo cp src/monitor-test.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/monitor-test.sh
sudo chown monitor:monitor /usr/local/bin/monitor-test.sh

sudo cp src/monitor-test.service /etc/systemd/system/
sudo cp src/monitor-test.timer /etc/systemd/system/

1.4 Запуск
Создадим симлинк ln -sf /bin/sleep /usr/local/bin/test Запустим процесс /usr/local/bin/test 10000 &
sudo systemctl daemon-reload
sudo systemctl enable monitor-test.timer
sudo systemctl start monitor-test.timer
