#!/bin/bash
set -e

until pg_isready -h $PRIMARY_HOST -U $POSTGRES_USER; do
  echo "Waiting for primary db"
  sleep 2
done

# Если данных нет — делаем бэкап с Primary
if [ -z "$(ls -A /var/lib/postgresql/data)" ]; then
  echo "Taking base backup from primary db"
  pg_basebackup -h $PRIMARY_HOST -D /var/lib/postgresql/data -U replicator -P -R -X stream
fi

exec docker-entrypoint.sh postgres