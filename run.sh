#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Запуск"

# 1. Сборка образов
echo -e "\n${YELLOW}📦 Сборка образов...${NC}"

build_image() {
  local name=$1
  local path=$2
  echo -ne "${BLUE}→ Собираем ${name}...${NC} "
  if docker build -t $name $path > /tmp/build_${name}.log 2>&1; then
    SIZE=$(docker images $name --format "{{.Size}}")
    echo -e "${GREEN}✓${NC} Размер: ${SIZE}"
  else
    echo -e "${RED}✗ Ошибка${NC}"
    tail -5 /tmp/build_${name}.log
    exit 1
  fi
}

build_image "axenta-app" "./app"
build_image "axenta-db-primary" "./db/primary"
build_image "axenta-db-replica" "./db/replica"
build_image "axenta-clickhouse" "./clickhouse"

# 2. Показать размеры
echo -e "\n${YELLOW}📊 Размеры образов:${NC}"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep axenta

# 3. Деплой стека
echo -e "\n${YELLOW}🐳 Деплой в Docker Swarm...${NC}"
docker stack deploy -c swarm/docker-stack.yml axenta

echo -ne "⏳ Ожидание запуска..."
for i in {1..60}; do
  echo -ne "."
  sleep 1
done
echo -e " ${GREEN}Готово${NC}"

# 4. Проверка сервисов
echo -e "\n${YELLOW}✅ Статус сервисов:${NC}"
docker service ls | grep axenta

# 5. Проверка готовности
echo -ne "🔍 Проверка готовности..."
for i in {1..30}; do
  RUNNING=$(docker service ls | grep axenta_app | grep -c "1/1" || true)
  if [ "$RUNNING" -gt 0 ]; then
    echo -e " ${GREEN}Готово${NC}"
    break
  fi
  echo -ne "."
  sleep 2
done

# 6. Тестовый запрос
echo -e "\n${YELLOW}📡 Тестовый запрос к приложению:${NC}"
RESPONSE=$(curl -s -X POST http://localhost:3000/event \
  -H "Content-Type: application/json" \
  -d '{"action": "script_test", "user_id": 999}' 2>&1)
if [ -n "$RESPONSE" ]; then
  echo -e "${GREEN}Ответ:${NC} $RESPONSE"
else
  echo -e "${RED}⚠ Нет ответа от приложения${NC}"
fi

# 7. Данные из БД
echo -e "\n${YELLOW}🗄️ PostgreSQL Primary:${NC}"
PRIMARY_ID=$(docker ps -q --filter name=axenta_db-primary | head -1)
if [ -n "$PRIMARY_ID" ]; then
  docker exec -it $PRIMARY_ID psql -U postgres -d eventsdb -c "SELECT id, data, created_at FROM events ORDER BY id DESC LIMIT 3;" 2>/dev/null || echo "⚠ Ошибка"
else
  echo "⚠ Контейнер не найден"
fi

echo -e "\n${YELLOW}🗄️ PostgreSQL Replica:${NC}"
REPLICA_ID=$(docker ps -q --filter name=axenta_db-replica | head -1)
if [ -n "$REPLICA_ID" ]; then
  docker exec -it $REPLICA_ID psql -U postgres -d eventsdb -c "SELECT id, data, created_at FROM events ORDER BY id DESC LIMIT 3;" 2>/dev/null || echo "⚠ Ошибка"
else
  echo "⚠ Контейнер не найден"
fi

echo -e "\n${YELLOW}🔥 ClickHouse (через HTTP):${NC}"
CH_RESPONSE=$(curl -s "http://localhost:8123/?query=SELECT%20%2A%20FROM%20events%20ORDER%20BY%20id%20DESC%20LIMIT%203&user=default&password=clickhouse_secret" 2>&1)
if [ -n "$CH_RESPONSE" ]; then
  echo "$CH_RESPONSE"
else
  echo "⚠ Нет данных"
fi

# 8. Очистка
echo -e "\n${YELLOW}🧹 Удалить стек, образы и контейнеры? (y/n)${NC}"
read -r CONFIRM

if [ "$CONFIRM" = "y" ]; then
  echo -e "\n${RED}→ Удаление...${NC}"
  docker stack rm axenta 2>/dev/null || true
  sleep 10
  docker rm -f $(docker ps -aq --filter name=axenta_) 2>/dev/null || true
  docker volume rm axenta_pg-primary-data axenta_pg-replica-data axenta_clickhouse-data 2>/dev/null || true
  docker network rm axenta_app-net 2>/dev/null || true
  docker rmi -f axenta-app axenta-db-primary axenta-db-replica axenta-clickhouse 2>/dev/null || true
  echo -e "${GREEN}✅ Очистка завершена${NC}"
else
  echo -e "${GREEN}✅ Пропущено${NC}"
fi

echo -e "\n${GREEN}🎉 Готово!${NC}"