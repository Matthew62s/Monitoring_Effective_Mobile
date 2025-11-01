# Monitoring_Effective_Mobile
Описание: bash‑скрипт + systemd‑таймер
1. Запускается при загрузке системы  
2. Выполняется каждую минуту  
3. Проверяет, жив ли процесс `test`  
4. Отправляет HTTPS‑запрос на `https://test.com/monitoring/test/api` (только если процесс запущен) (из проблем домен в продаже) 
5. Логирует в `/var/log/monitoring.log`:
   * перезапуск процесса  
   * недоступность сервера мониторинга 'https://test.com/monitoring/test/api'


Настройка и работа:
ОС Debian 13.1.0
Для тестового задания все действия проводил под root(не рекомендуется)
1. Сделаем имитацию процесса test:
   Создадим симлинк ln -sf /bin/sleep /usr/local/bin/test
   Запустим процесс /usr/local/bin/test 10000 &

2. Склонировать репозиторий в директорию
   Скопировать monitor-test.sh в /usr/local/bin/monitor-test.sh
   Скопировать monitor-test.service в /etc/systemd/system/monitor-test.service
   Скопировать monitor-test.timer в /etc/systemd/system/monitor-test.timer

   systemctl enable --now monitor-test.timer
   systemctl start monitor-test.timer

Вывод: tail -f /var/log/monitoring.log
