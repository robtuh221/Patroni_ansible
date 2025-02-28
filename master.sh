#!/bin/bash

echo "Вас приветствует Мастер установки Баз Данных TWO_UNITS!"
echo "Далее будут предложены ввести данные от 3 хостов баз данных"
echo "Все данные будут записаны в локальные файлы инсталяции после удалены"
echo "Автор Тухватуллин Роберт"
sleep 1

# Блок по сбору данных о установливаемой базы данных
collection_of_information() {
    # Блок сбора IP-адресов доступа
    echo "Укажите IP-адреса доступа к хостам"
    sleep 1
    echo
    # Запрос IP-адреса для node1
    read -p "Укажите IP-адрес для 1 хоста: " ip_address_node1

    # Запрос IP-адреса для node2
    read -p "Укажите IP-адрес для 2 хоста: " ip_address_node2

    # Запрос IP-адреса для node3
    read -p "Укажите IP-адрес для 3 хоста: " ip_address_node3

    # Замена IP-адресов в файле hosts.ini
    sed -i "/^node1/s/ansible_host=[^ ]*/ansible_host=$ip_address_node1/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node2/s/ansible_host=[^ ]*/ansible_host=$ip_address_node2/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node3/s/ansible_host=[^ ]*/ansible_host=$ip_address_node3/" /tmp/Patroni/inventory/hosts.ini

    # Блок сбора имен пользователей
    echo "Укажите имена пользователей хостов"
    sleep 1
    echo
    # Запрос имени пользователя для node1
    read -p "Укажите имя пользователя для 1 хоста: " hostname_node1

    # Запрос имени пользователя для node2
    read -p "Укажите имя пользователя для 2 хоста: " hostname_node2

    # Запрос имени пользователя для node3
    read -p "Укажите имя пользователя для 3 хоста: " hostname_node3

    # Замена имен пользователей в файле hosts.ini
    sed -i "/^node1/s/ansible_user=[^ ]*/ansible_user=$hostname_node1/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node2/s/ansible_user=[^ ]*/ansible_user=$hostname_node2/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node3/s/ansible_user=[^ ]*/ansible_user=$hostname_node3/" /tmp/Patroni/inventory/hosts.ini

    # Блок сбора паролей хостов
    echo "Укажите пароли хостов"
    sleep 1
    echo
    # Запрос пароля для node1
    read -p "Укажите пароль для 1 хоста: " password_host1

    # Запрос пароля для node2
    read -p "Укажите пароль для 2 хоста: " password_host2

    # Запрос пароля для node3
    read -p "Укажите пароль для 3 хоста: " password_host3

    # Замена паролей в файле hosts.ini
    sed -i "/^node1/s/ansible_password=[^ ]*/ansible_password=$password_host1/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node2/s/ansible_password=[^ ]*/ansible_password=$password_host2/" /tmp/Patroni/inventory/hosts.ini
    sed -i "/^node3/s/ansible_password=[^ ]*/ansible_password=$password_host3/" /tmp/Patroni/inventory/hosts.ini

# Блок сбора ip-адресов внутренней сети баз данных 
    echo "Укажите ip-адреса внутренней сети баз данных"
    sleep 1
    echo
    # Запрос пароля для node1
    read -p "Укажите ip-адрес для 1 хоста: " ip_data_base1

    # Запрос пароля для node2
    read -p "Укажите ip-адрес для 2 хоста: " ip_data_base2

    # Запрос пароля для node3
    read -p "Укажите ip-адрес для 3 хоста: " ip_data_base3

    sed -i "/^etcd_host:/s/etcd_host: [^ ]*/etcd_host: $ip_data_base1/" /tmp/Patroni/host_vars/node1.yml

    # Замена IP-адресов в файле host_vars/node2.yml
    sed -i "/^etcd_host:/s/etcd_host: [^ ]*/etcd_host: $ip_data_base2/" /tmp/Patroni/host_vars/node2.yml

    # Замена IP-адресов в файле host_vars/node3.yml
    sed -i "/^etcd_host:/s/etcd_host: [^ ]*/etcd_host: $ip_data_base3/" /tmp/Patroni/host_vars/node3.yml

# Блок сбора vip-ip-адреса базы для сервиса keepalived
    echo "Укажите vip-ip-адрес баз данных"
    sleep 1
    echo 
    read -p "Укажите ip-адрес: " vip_ip
    sed -i "/^vip_address:/s/vip_address: [^ ]*/vip_address: $vip_ip/" /tmp/Patroni/host_vars/node1.yml

# Блок сбора директории установки
    echo "Укажите директорию для установки базы данных"
    sleep 1
    echo
    read -p "Укажите директорию: " data_dir

    # Замена директории в файле host_vars/node1.yml
    sed -i "/^data_dir:/s|data_dir: [^ ]*|data_dir: $data_dir|" /tmp/Patroni/host_vars/node1.yml

# Блок сбора интерфейса ВМ для сервиса keepalived
    echo "Укажите имя интерфейса сети баз данных"
    sleep 1
    echo
    # Запрос пароля для node1
    read -p "Укажите интерфейс для 1 хоста: " storage_interface1

    # Запрос пароля для node2
    read -p "Укажите интерфейс для 2 хоста: " storage_interface2

    # Запрос пароля для node3
    read -p "Укажите интерфейс для 3 хоста: " storage_interface3

    sed -i "/^storage_interface:/s/storage_interface: [^ ]*/storage_interface: $storage_interface1/" /tmp/Patroni/host_vars/node1.yml

    # Замена IP-адресов в файле host_vars/node2.yml
    sed -i "/^storage_interface:/s/storage_interface: [^ ]*/storage_interface: $storage_interface2/" /tmp/Patroni/host_vars/node2.yml

    # Замена IP-адресов в файле host_vars/node3.yml
    sed -i "/^storage_interface:/s/storage_interface: [^ ]*/storage_interface: $storage_interface3/" /tmp/Patroni/host_vars/node3.yml

    # Блок сбора пароля суперюзера базы
    echo "Укажите пароль для пользователя postgres базы данных"
    sleep 1
    echo
    read -p "Укажите пароль: " db_pass

    # Замена директории в файле host_vars/node1.yml
    sed -i "/^db_pass:/s|db_pass: [^ ]*|db_pass: $db_pass|" /tmp/Patroni/host_vars/node1.yml
}

# Выбор баз из списка
echo "Выберете желаемую базу данных"
echo "1. Tantor (Astra Linux)"
echo "2. Postgres Vanila (Alt Linux)"
echo "3. Postgres Pro (Alt Linux)"

read -p "Укажите значение (1-3): " answer
case $answer in
    1)
        echo "Вы выбрали Tantor (Astra Linux)"
        collection_of_information
        echo "Сбор данных завершен, приступаем у установке"
        ansible-playbook -i /tmp/Patroni/inventory/hosts.ini /tmp/Patroni/tantor_playbook/tantor_db.yml
        ;;
    2)
        echo "Вы выбрали Postgres Vanila (Alt Linux)"
        ;;
    3)
        echo "Вы выбрали Postgres Pro (Alt Linux)"
        ansible-playbook -i /tmp/Patroni/inventory/hosts.ini /tmp/Patroni/postgres_playbooks/postgres_pro_db.yml
        ;;
    *)
        echo "Неверный выбор. Пожалуйста, укажите значение от 1 до 3."
        ;;
esac
